# Manage-data page: ODS backup export, imports (OpenAppointments ODS or a raw
# 10to8 export CSV; dry-run analyze, then a background job with progress
# polling) and the database reset.
class ImportController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  MAX_UPLOAD_SIZE = 100.megabytes

  before_action :require_session, except: [ :index ]
  before_action :forbid_unless_system_settings_edit, except: [ :index ]

  def index
    return unless require_backend_page!(:system_settings)
    return head :forbidden unless can?(:edit, :system_settings)

    backend_page_vars(page_title: helpers.lang("manage_data"), active_menu: "system_settings")
    render :index
  end

  # POST /import/export - build a backup pair (ODS + zip) in the background.
  def export
    export_id = SecureRandom.hex(12)
    BackupExportJob.perform_later(export_id: export_id)
    BackupExportJob.write_status(export_id, { state: "queued" })
    render json: { success: true, export_id: export_id }
  end

  # GET /import/export_status
  def export_status
    render json: BackupExportJob.read_status(params[:export_id].to_s) || { state: "unknown" }
  end

  # GET /import/backups - the kept backups, newest first.
  def backups
    render json: {
      backups: BackupExport.list.map { |backup|
        {
          date: backup[:date].strftime("%Y-%m-%d %H:%M"),
          files: backup[:files].transform_values { |name|
            { name: name, size: helpers.number_to_human_size(File.size(BackupExport.dir.join(name))) }
          }
        }
      }
    }
  end

  # GET /import/download_backup?name=... - admin-gated backup download.
  def download_backup
    name = params[:name].to_s
    path = BackupExport.dir.join(name)
    raise ArgumentError, "Unknown backup." unless BackupExport.valid_name?(name) && File.exist?(path)

    send_file path, filename: name,
                    type: name.end_with?(".zip") ? "application/zip" : Ods::MIMETYPE
  rescue ArgumentError => e
    json_exception(e)
  end

  # POST /import/analyze - dry run: parse the upload and return the counts.
  def analyze
    data = extractor_class.new(
      uploaded_file_path, days_back: params[:days_back] || 21, days_forward: params[:days_forward] || 21
    ).call
    render json: {
      success: true,
      summary: {
        staff: data[:staff].size, services: data[:services].size,
        customers: data[:customers].size, appointments: data[:appointments].size,
        settings: Array(data[:settings]).size,
        do_not_contact: data[:customers].count { |customer| customer[:do_not_contact] }
      }
    }
  rescue ArgumentError, CSV::MalformedCSVError => e
    json_exception(e)
  ensure
    cleanup_upload
  end

  # POST /import/start - persist the upload and run the import in the background.
  def start
    import_type = extractor_type
    import_id = SecureRandom.hex(12)
    path = Rails.root.join("tmp", "manage-data-import-#{import_id}").to_s
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.cp(uploaded_file_path, path)

    images_path = nil
    if params[:images_file].respond_to?(:tempfile)
      raise ArgumentError, "The file is too large." if params[:images_file].size > MAX_UPLOAD_SIZE

      images_path = "#{path}-images.zip"
      FileUtils.cp(params[:images_file].tempfile.path, images_path)
    end

    TenToEightImportJob.perform_later(
      import_id: import_id, file_path: path, images_path: images_path, import_type: import_type,
      phases: Array(params[:phases]) & TenToEight::Load::PHASES,
      days_back: (params[:days_back] || 21).to_i, days_forward: (params[:days_forward] || 21).to_i,
      create_providers: ActiveModel::Type::Boolean.new.cast(params[:create_providers]) || false
    )
    TenToEightImportJob.write_status(import_id, { state: "queued" })
    render json: { success: true, import_id: import_id }
  rescue ArgumentError => e
    json_exception(e)
  ensure
    cleanup_upload
  end

  # GET /import/status
  def status
    payload = TenToEightImportJob.read_status(params[:import_id].to_s)
    render json: payload || { state: "unknown" }
  end

  # POST /import/reset - database reset behind a typed confirmation. With
  # full: admins and settings go too and the session ends.
  def reset
    unless params[:confirmation] == "I KNOW WHAT I AM DOING"
      raise ArgumentError, "Type I KNOW WHAT I AM DOING to confirm."
    end

    full = ActiveModel::Type::Boolean.new.cast(params[:full]) || false
    ResetDatabase.run(full: full)
    reset_session if full
    render json: { success: true, full: full }
  rescue StandardError => e
    reset_session if full
    json_exception(e)
  end

  private

  def extractor_type
    type = params[:import_type].presence || "ten_to_eight"
    raise ArgumentError, "Unknown import type." unless TenToEightImportJob::EXTRACTORS.key?(type)

    type
  end

  def extractor_class = TenToEightImportJob::EXTRACTORS.fetch(extractor_type)

  def uploaded_file_path
    file = params[:file]
    raise ArgumentError, "No file provided." unless file.respond_to?(:tempfile)
    raise ArgumentError, "The file is too large." if file.size > MAX_UPLOAD_SIZE

    file.tempfile.path
  end

  def cleanup_upload
    [ params[:file], params[:images_file] ].each do |file|
      file.tempfile.close! if file.respond_to?(:tempfile)
    rescue StandardError
      nil
    end
  end
end
