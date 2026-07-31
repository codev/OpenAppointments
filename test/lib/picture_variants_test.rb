require "test_helper"

class PictureVariantsTest < ActiveSupport::TestCase
  test "attach keeps the original and stores padded and zoomed 400x400 variants" do
    service = services(:haircut)
    PictureVariants.attach(service, file_fixture("picture.png").to_s,
                           filename: "picture.png", content_type: "image/png")

    assert service.picture.attached?
    assert service.picture_padded.attached?
    assert service.picture_zoomed.attached?

    assert_equal file_fixture("picture.png").binread, service.picture.download,
                 "the original must be stored byte for byte"
    assert_equal "picture.png", service.picture.filename.to_s

    padded = MiniMagick::Image.read(service.picture_padded.download)
    assert_equal [ PictureVariants::SIZE, PictureVariants::SIZE ], padded.dimensions

    zoomed = MiniMagick::Image.read(service.picture_zoomed.download)
    assert_equal [ PictureVariants::SIZE, PictureVariants::SIZE ], zoomed.dimensions
  end

  test "a corrupt image raises a clean argument error" do
    Tempfile.create([ "bad", ".png" ]) do |file|
      file.write("not an image")
      file.flush
      assert_raises(ArgumentError) do
        PictureVariants.attach(services(:haircut), file.path, filename: "bad.png", content_type: "image/png")
      end
    end
  end

  test "the picture style settings pick the served variant per record type" do
    service = services(:haircut)
    PictureVariants.attach(service, file_fixture("picture.png").to_s,
                           filename: "picture.png", content_type: "image/png")

    Setting.set("picture_style_services", "border")
    assert_includes EaRows.picture_url(service), "padded-picture"

    Setting.set("picture_style_services", "zoomed")
    assert_includes EaRows.picture_url(service), "zoomed-picture"

    # Unprocessed records fall back to the original.
    other = Service.create!(name: "Fallback", duration: 30)
    other.picture.attach(io: StringIO.new(file_fixture("picture.png").binread),
                         filename: "raw.png", content_type: "image/png")
    assert_includes EaRows.picture_url(other), "raw.png"
  end
end
