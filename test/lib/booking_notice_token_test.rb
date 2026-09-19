require "test_helper"

# {{Booking Notice}} carries the notice as plain text: email bodies and SMS are
# rendered with HTML escaped, so tags are dropped and block breaks kept.
class BookingNoticeTokenTest < ActiveSupport::TestCase
  test "the token is listed and renders the notice as plain text" do
    Setting.set("booking_notice_content", "<p>Bring <b>cash</b>.</p><p>No dogs.<br>Thanks</p>")
    assert_includes Messaging::Template::TOKENS, "Booking Notice"
    assert_equal "Bring cash.\nNo dogs.\nThanks", Messaging::Template.base_context["Booking Notice"]
    assert_equal "Note: Bring cash.\nNo dogs.\nThanks",
                 Messaging::Template.render("Note: {{Booking Notice}}", Messaging::Template.base_context)
  end

  test "entities are decoded so messages carry the characters, not the codes" do
    Setting.set("booking_notice_content", "<p>Cuts &amp; colour &lt;on the day&gt;</p>")
    assert_equal "Cuts & colour <on the day>", Messaging::Template.base_context["Booking Notice"]
  end

  test "an empty notice renders an empty token" do
    Setting.set("booking_notice_content", "")
    assert_equal "", Messaging::Template.base_context["Booking Notice"]
  end
end
