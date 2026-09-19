require "test_helper"

# Debug on Messages > Settings redirects mail that bypasses the Message log
# (password resets, failure alerts) as well.
class DebugInterceptTest < ActionMailer::TestCase
  test "debug redirects a password reset email and marks the original recipient" do
    Setting.set("messages_enabled", "debug")
    Setting.set("messages_intercept_email", "dev@example.org")
    mail = AccountMailer.password_reset_link("jane@example.org", "https://example.org/reset/abc").deliver_now
    assert_equal [ "dev@example.org" ], mail.to
    mail.parts.select { |part| part.mime_type.to_s.start_with?("text/") }.each do |part|
      assert_match "ORIGINAL-TO: jane@example.org", part.body.to_s
    end
  end

  test "on leaves a password reset email alone" do
    Setting.set("messages_enabled", "1")
    mail = AccountMailer.password_reset_link("jane@example.org", "https://example.org/reset/abc").deliver_now
    assert_equal [ "jane@example.org" ], mail.to
    assert_no_match "ORIGINAL-TO", mail.html_part.body.to_s
  end
end
