# Picture field on a CrudPage form: <resource>[picture] attaches (with the padded
# and zoomed variants), <resource>[remove_picture] detaches.
module RecordPicture
  private

  def save_record_picture(record, fields)
    if ActiveModel::Type::Boolean.new.cast(fields[:remove_picture])
      %i[picture picture_padded picture_zoomed].each { |name| record.public_send(name).purge }
    end
    picture = fields[:picture]
    return unless picture.respond_to?(:content_type)

    PictureUpload.validate!(picture)
    PictureVariants.attach(record, picture.tempfile.path, filename: picture.original_filename,
                                                          content_type: picture.content_type)
  end
end
