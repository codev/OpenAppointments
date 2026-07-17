# Import page: loads a raw 10to8 export CSV (dry-run analyze, then a background
# import job with progress polling) and offers the business-data reset.
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

    backend_page_vars(page_title: helpers.lang("import_data"), active_menu: "system_settings")
    render :index
  end

  # POST /import/analyze - dry run: parse the upload and return the counts.
  def analyze
    data = TenToEight::Extract.new(
      uploaded_file_path, days_back: params[:days_back] || 21, days_forward: params[:days_forward] || 21
    ).call
    render json: {
      success: true,
      summary: {
        staff: data[:staff].size, services: data[:services].size,
        customers: data[:customers].size, appointments: data[:appointments].size,
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
    import_id = SecureRandom.hex(12)
    path = Rails.root.join("tmp", "ten-to-eight-#{import_id}.csv").to_s
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.cp(uploaded_file_path, path)

    TenToEightImportJob.perform_later(
      import_id: import_id, file_path: path,
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

  # POST /import/reset - business-data reset behind a typed confirmation.
  def reset
    raise ArgumentError, "Type RESET to confirm." unless params[:confirmation] == "RESET"

    ResetDatabase.run
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e)
  end

  private

  def uploaded_file_path
    file = params[:file]
    raise ArgumentError, "No file provided." unless file.respond_to?(:tempfile)
    raise ArgumentError, "The file is too large." if file.size > MAX_UPLOAD_SIZE

    file.tempfile.path
  end

  def cleanup_upload
    params[:file].tempfile.close! if params[:file].respond_to?(:tempfile)
  rescue StandardError
    nil
  end
end
