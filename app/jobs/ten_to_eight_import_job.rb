# Runs a 10to8 CSV import in the background; progress and results land in the
# cache under the import id polled by the import page.
class TenToEightImportJob < ApplicationJob
  queue_as :default

  CACHE_TTL = 1.hour

  EXTRACTORS = { "ods" => OdsExtract, "ten_to_eight" => TenToEight::Extract }.freeze

  # Injectable for tests (the test env cache is a null store).
  class_attribute :status_store, default: nil

  def self.store = status_store || Rails.cache

  def self.status_key(import_id) = "ten-to-eight-import-#{import_id}"

  def self.read_status(import_id) = store.read(status_key(import_id))

  def self.write_status(import_id, payload)
    store.write(status_key(import_id), payload, expires_in: CACHE_TTL)
  end

  def perform(import_id:, file_path:, phases:, days_back:, days_forward:, create_providers:,
              import_type: "ten_to_eight", today: nil)
    write_status(import_id, state: "running", phase: "extract")

    # A zip bundle carries the ODS plus the images its picture columns reference.
    extract_path = file_path
    images_dir = nil
    if import_type == "ods" && OdsBundle.bundle?(file_path)
      images_dir = "#{file_path}-bundle"
      extract_path = OdsBundle.unpack(file_path, images_dir)
      raise ArgumentError, "No ODS file found in the zip." unless extract_path
    end

    data = EXTRACTORS.fetch(import_type).new(
      extract_path, today: today ? Date.parse(today) : Date.current,
      days_back: days_back, days_forward: days_forward
    ).call

    result = TenToEight::Load.new(
      data, phases: phases, create_providers: create_providers, images_dir: images_dir,
      progress: ->(phase) { write_status(import_id, state: "running", phase: phase) }
    ).call

    write_status(import_id, state: "completed", counts: result[:counts], errors: result[:errors])
  rescue StandardError => e
    write_status(import_id, state: "failed", error: e.message)
    raise
  ensure
    FileUtils.rm_f(file_path)
    FileUtils.rm_rf("#{file_path}-bundle")
  end

  private

  def write_status(import_id, payload)
    self.class.write_status(import_id, payload)
  end
end
