require "image_processing/mini_magick"

# Stored picture derivatives, processed once at upload/import time (the Active
# Storage variant processor is disabled). The original upload is kept untouched
# in picture (and is what backups carry); display uses one of two 400x400
# variants per the picture_style_* settings: padded (white border) or zoomed
# (smallest edge scaled to 400, centre cropped).
module PictureVariants
  SIZE = 400

  module_function

  def attach(record, path, filename:, content_type:)
    padded = ImageProcessing::MiniMagick.source(path)
                                        .resize_and_pad(SIZE, SIZE, background: "#ffffff", gravity: "center")
                                        .call
    zoomed = ImageProcessing::MiniMagick.source(path).resize_to_fill(SIZE, SIZE).call
    record.picture.attach(io: File.open(path), filename: filename, content_type: content_type)
    record.picture_padded.attach(io: File.open(padded.path), filename: "padded-#{filename}",
                                 content_type: content_type)
    record.picture_zoomed.attach(io: File.open(zoomed.path), filename: "zoomed-#{filename}",
                                 content_type: content_type)
  rescue ImageProcessing::Error, MiniMagick::Error => e
    raise ArgumentError, "Could not process the picture: #{e.message}"
  ensure
    [ padded, zoomed ].each { |file| File.delete(file.path) if file && File.exist?(file.path) }
  end
end
