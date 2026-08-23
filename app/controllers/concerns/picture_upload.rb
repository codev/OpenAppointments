# Picture field rules for backend records (users, services, categories).
module PictureUpload
  ALLOWED_PICTURE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_PICTURE_SIZE = 5.megabytes

  def self.validate!(file)
    raise ArgumentError, "No picture provided." unless file.respond_to?(:content_type)
    raise ArgumentError, "Unsupported picture type." unless ALLOWED_PICTURE_TYPES.include?(file.content_type)
    raise ArgumentError, "The picture is too large (5 MB maximum)." if file.size > MAX_PICTURE_SIZE
  end
end
