# Reprocesses already-attached pictures into the bounded detail + thumbnail
# pair. Records from before picture processing existed have no thumbnail;
# those are the ones picked up, so re-runs are cheap.
module PictureBackfill
  MODELS = %w[ServiceCategory Service User].freeze

  module_function

  def run
    processed = 0
    MODELS.each do |model_name|
      model_name.constantize.with_attached_picture.find_each do |record|
        next unless record.picture.attached?
        next if record.picture_padded.attached? && record.picture_zoomed.attached?

        blob = record.picture.blob
        Tempfile.create([ "picture-backfill", File.extname(blob.filename.to_s) ]) do |file|
          file.binmode
          record.picture.download { |chunk| file.write(chunk) }
          file.flush
          PictureVariants.attach(record, file.path, filename: blob.filename.to_s,
                                                    content_type: blob.content_type)
        end
        processed += 1
      rescue ArgumentError, ActiveStorage::Error => e
        Rails.logger.warn("Picture backfill skipped #{model_name} #{record.id}: #{e.message}")
      end
    end
    processed
  end
end
