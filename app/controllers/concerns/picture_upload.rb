# Picture upload/removal for backend records (users, services, categories).
# Controllers define picture_record and picture_permission_resource.
module PictureUpload
  ALLOWED_PICTURE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_PICTURE_SIZE = 5.megabytes

  # POST /<resource>/:id/picture with a picture file, or remove=1 to detach.
  def save_picture
    raise ArgumentError, "Forbidden" if cannot?(:edit, picture_permission_resource)

    record = picture_record

    if ActiveModel::Type::Boolean.new.cast(params[:remove])
      record.picture.purge
      return render json: { success: true, picture_url: nil }
    end

    file = params[:picture]
    raise ArgumentError, "No picture provided." unless file.respond_to?(:content_type)
    raise ArgumentError, "Unsupported picture type." unless ALLOWED_PICTURE_TYPES.include?(file.content_type)
    raise ArgumentError, "The picture is too large (5 MB maximum)." if file.size > MAX_PICTURE_SIZE

    record.picture.attach(file)
    render json: { success: true, picture_url: EaRows.picture_url(record) }
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    json_exception(e)
  end
end
