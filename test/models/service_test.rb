require "test_helper"

# Service descriptions are rich text: sanitised on save, whichever path writes them.
class ServiceTest < ActiveSupport::TestCase
  test "the description keeps formatting and loses scripts and event handlers" do
    service = services(:haircut)
    service.update!(description: '<p style="text-align: center;">Dry <strong>cuts</strong></p><ul><li>No wash</li></ul>' \
                                 '<script>alert(1)</script><a href="https://example.org" onclick="x()">Book</a>')
    saved = service.reload.description
    assert_includes saved, '<p style="text-align:center;">Dry <strong>cuts</strong></p>'
    assert_includes saved, "<ul><li>No wash</li></ul>"
    assert_includes saved, '<a href="https://example.org">Book</a>'
    assert_not_includes saved, "<script"
    assert_not_includes saved, "onclick"
  end

  test "a blank description stays blank" do
    service = services(:haircut)
    service.update!(description: "")
    assert_equal "", service.reload.description
    service.update!(description: nil)
    assert_nil service.reload.description
  end
end
