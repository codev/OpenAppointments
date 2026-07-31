require "test_helper"

class PictureBackfillTest < ActiveSupport::TestCase
  test "run processes pictures without thumbnails and skips processed ones" do
    service = services(:haircut)
    service.picture.attach(io: StringIO.new(file_fixture("picture.png").binread),
                           filename: "picture.png", content_type: "image/png")
    assert_not service.picture_padded.attached?

    assert_equal 1, PictureBackfill.run
    service.reload
    assert service.picture_padded.attached?
    assert service.picture_zoomed.attached?
    assert_equal file_fixture("picture.png").binread, service.picture.download,
                 "the original must survive the backfill"
    padded = MiniMagick::Image.read(service.picture_padded.download)
    assert_equal [ PictureVariants::SIZE, PictureVariants::SIZE ], padded.dimensions

    assert_equal 0, PictureBackfill.run, "already-processed records must be skipped"
  end
end
