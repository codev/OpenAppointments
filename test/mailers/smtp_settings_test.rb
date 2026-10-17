require "test_helper"

# Outgoing mail goes through the admin-entered SMTP server when one is set on
# Messages > Settings, whichever application mailer sends it; otherwise the
# environment's delivery method stands. Maintainer alerts stay on the platform
# mailer, as crash reports do.
class SmtpSettingsTest < ActionMailer::TestCase
  def configure_smtp(host)
    Setting.set("messages_email_mode", "smtp")
    Setting.set("messages_email_smtp_host", host)
    Setting.set("messages_email_smtp_username", "mailer")
    Setting.set("messages_email_smtp_password", "secret")
  end

  def outgoing_message
    Message.create!(direction: "outgoing", channel: "email", audience: "customer",
                    to_address: "someone@example.org", subject: "Booked", body: "See you soon", status: "queued")
  end

  test "every mailer uses the admin SMTP server when one is configured" do
    configure_smtp("smtp.example.org")
    mails = [
      AccountMailer.password_reset_link("jane@example.org", "https://example.org/reset/abc"),
      MessagesMailer.outgoing(outgoing_message)
    ]
    mails.each do |mail|
      assert_kind_of Mail::SMTP, mail.delivery_method, "#{mail.subject} should go via SMTP"
      assert_equal "smtp.example.org", mail.delivery_method.settings[:address]
      assert_equal "mailer", mail.delivery_method.settings[:user_name]
    end
  end

  test "mail falls back to the environment delivery without an SMTP host or in server mode" do
    configure_smtp("")
    assert_kind_of Mail::TestMailer, AccountMailer.password_reset_link("jane@example.org", "https://example.org/reset/abc").delivery_method

    configure_smtp("smtp.example.org")
    Setting.set("messages_email_mode", "server")
    assert_kind_of Mail::TestMailer, MessagesMailer.outgoing(outgoing_message).delivery_method
  end

  test "maintainer alerts keep the platform mailer" do
    configure_smtp("smtp.example.org")
    assert_kind_of Mail::TestMailer, AlertMailer.login_attempts("203.0.113.9", "jane").delivery_method
  end
end
