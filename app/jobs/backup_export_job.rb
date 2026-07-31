# Builds a backup pair in the background; state lands in the cache under the
# export id polled by the manage-data page.
class BackupExportJob < ApplicationJob
  queue_as :default

  CACHE_TTL = 1.hour

  # Injectable for tests (the test env cache is a null store).
  class_attribute :status_store, default: nil

  def self.store = status_store || Rails.cache

  def self.status_key(export_id) = "backup-export-#{export_id}"

  def self.read_status(export_id) = store.read(status_key(export_id))

  def self.write_status(export_id, payload)
    store.write(status_key(export_id), payload, expires_in: CACHE_TTL)
  end

  def perform(export_id:)
    self.class.write_status(export_id, state: "running")
    files = BackupExport.run
    self.class.write_status(export_id, state: "completed", files: files)
  rescue StandardError => e
    Rails.logger.error("Backup export failed: #{e.message}")
    self.class.write_status(export_id, state: "failed", error: e.message)
  end
end
