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
              import_type: "ten_to_eight", images_path: nil, today: nil)
    write_status(import_id, state: "running", phase: "extract")

    # The optional images zip carries the pictures the sheets reference by filename.
    images_dir = nil
    if images_path
      images_dir = "#{file_path}-images"
      OdsBundle.unpack(images_path, images_dir)
    end

    data = EXTRACTORS.fetch(import_type).new(
      file_path, today: today ? Date.parse(today) : Date.current,
      days_back: days_back, days_forward: days_forward
    ).call

    result = TenToEight::Load.new(
      data, phases: phases, create_providers: create_providers, images_dir: images_dir,
      progress: ->(phase) { write_status(import_id, state: "running", phase: phase) }
    ).call

    write_status(import_id, state: "completed", counts: result[:counts], errors: result[:errors])
  rescue StandardError, ScriptError => e
    write_status(import_id, state: "failed", error: e.message)
    raise
  ensure
    FileUtils.rm_f(file_path)
    FileUtils.rm_f(images_path) if images_path
    FileUtils.rm_rf("#{file_path}-images")
  end

  private

  def write_status(import_id, payload)
    self.class.write_status(import_id, payload)
  end
end
