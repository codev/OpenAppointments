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
