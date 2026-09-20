require "test_helper"

class MessageDeliveryJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper
  def failing_message
    Message.create!(channel: "nonexistent", direction: "outgoing", to_address: "+447700900111", body: "hi")
  end

  test "a failed delivery emails the maintainer when the alert is on" do
    Setting.set("messages_failure_alert", "1")
    message = failing_message

    assert_enqueued_emails 1 do
      MessageDeliveryJob.perform_now(message.id)
    end
    assert_equal "failed", message.reload.status

    Setting.set("messages_failure_alert_emails", "ops@example.org, marc@example.org")
    email = AlertMailer.message_failed(message)
    assert_equal %w[ops@example.org marc@example.org], email.to
    assert_match "Provider: nonexistent", email.text_part&.body&.to_s || email.body.to_s
  end

  test "the alert goes to every admin when no list is configured" do
    Setting.set("messages_failure_alert_emails", "")
    assert_equal User.admins.pluck(:email), AlertMailer.failure_recipients
  end

  test "no alert email when the option is off" do
    Setting.set("messages_failure_alert", "0")
    message = failing_message

    assert_no_enqueued_emails do
      MessageDeliveryJob.perform_now(message.id)
    end
    assert_equal "failed", message.reload.status
  end
end

class MessageDeliveryDebugTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    Setting.set("messages_enabled", "debug")
    Setting.set("messages_intercept_email", "dev@example.org")
    Setting.set("messages_intercept_phone", "+447700900123")
  end

  test "debug counts as notifications on" do
    assert Messaging.enabled?
    assert Messaging.debug?
    Setting.set("messages_enabled", "0")
    assert_not Messaging.enabled?
    assert_not Messaging.debug?
  end

  test "debug sends an email message to the intercept address with the original recipient on top" do
    message = Message.create!(channel: "email", direction: "outgoing", to_address: "jane@example.org",
                              subject: "Your appointment", body: "See you soon")
    perform_enqueued_jobs do
      MessageDeliveryJob.perform_now(message.id)
    end
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "dev@example.org" ], mail.to
    body = (mail.html_part || mail).body.to_s
    assert_match "ORIGINAL-TO: jane@example.org", body
    assert_match "See you soon", body
    assert_equal "sent", message.reload.status
    assert_equal "dev@example.org", message.to_address
    assert_equal "ORIGINAL-TO: jane@example.org\nSee you soon", message.body
  end

  test "debug redirects an sms message to the intercept phone before the adapter sees it" do
    message = Message.create!(channel: "smsgateway", direction: "outgoing", to_address: "+447971862965", body: "See you soon")
    MessageDeliveryJob.perform_now(message.id)
    message.reload
    assert_equal "+447700900123", message.to_address
    assert_equal "ORIGINAL-TO: +447971862965\nSee you soon", message.body
  end

  test "on and off leave the recipient alone" do
    Setting.set("messages_enabled", "1")
    message = Message.create!(channel: "smsgateway", direction: "outgoing", to_address: "+447971862965", body: "See you soon")
    MessageDeliveryJob.perform_now(message.id)
    message.reload
    assert_equal "+447971862965", message.to_address
    assert_equal "See you soon", message.body
  end
end
