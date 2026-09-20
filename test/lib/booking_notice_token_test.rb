require "test_helper"

# {{Booking Notice}} carries the notice as plain text: email bodies and SMS are
# rendered with HTML escaped, so tags are dropped and block breaks kept. The
# notice is only converted when a template uses the token.
class BookingNoticeTokenTest < ActiveSupport::TestCase
  def render(template)
    Messaging::Template.render(template, Messaging::Template.base_context)
  end

  test "the token is listed and renders the notice as plain text" do
    Setting.set("booking_notice_content", "<p>Bring <b>cash</b>.</p><p>No dogs.<br>Thanks</p>")
    assert_includes Messaging::Template::TOKENS, "Booking Notice"
    assert_equal "Note: Bring cash.\nNo dogs.\nThanks", render("Note: {{Booking Notice}}")
  end

  test "entities are decoded so messages carry the characters, not the codes" do
    Setting.set("booking_notice_content", "<p>Cuts &amp; colour &lt;on the day&gt;</p>")
    assert_equal "Cuts & colour <on the day>", render("{{Booking Notice}}")
  end

  test "an empty notice renders an empty token" do
    Setting.set("booking_notice_content", "")
    assert_equal "", render("{{Booking Notice}}")
  end

  test "context values can be callables resolved only when their token is used" do
    calls = 0
    context = { "Lazy" => -> { calls += 1; "later" }, "Plain" => "now" }
    assert_equal "now", Messaging::Template.render("{{Plain}}", context)
    assert_equal 0, calls
    assert_equal "later later", Messaging::Template.render("{{Lazy}} {{lazy}}", context)
    assert_equal 2, calls
    assert Messaging::Template.base_context["Booking Notice"].respond_to?(:call)
  end
end
