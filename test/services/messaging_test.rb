require "test_helper"
require "webmock/minitest"

class MessagingTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  test "channel lookup and enablement" do
    assert_equal Messaging::EmailChannel, Messaging.channel("email")
    assert_nil Messaging.channel("bogus")
    # Email is on by default; SMS channels need credentials before they count as enabled.
    assert_includes Messaging.enabled_channel_keys, "email"
    assert_not_includes Messaging.enabled_channel_keys, "twilio"
  end

  test "template rendering is case-insensitive and drops unknown tokens" do
    rendered = Messaging::Template.render("Hi {{customer name}} {{Unknown Thing}}!", { "Customer Name" => "JX" })
    assert_equal "Hi JX !", rendered
  end

  test "delivery job sends email and marks the message sent" do
    message = Message.create!(direction: "outgoing", channel: "email", audience: "customer",
                              to_address: "c@example.org", subject: "Hi", body: "Hello", status: "queued")
    assert_emails 1 do
      MessageDeliveryJob.perform_now(message.id)
    end
    assert_equal "sent", message.reload.status
  end

  test "delivery job records failures without raising" do
    Setting.set("messages_twilio_account_sid", "AC1")
    Setting.set("messages_twilio_auth_token", "t")
    Setting.set("messages_twilio_from", "+15005550006")
    stub_request(:post, %r{api\.twilio\.com}).to_return(status: 401, body: "no")

    message = Message.create!(direction: "outgoing", channel: "twilio", audience: "customer",
                              to_address: "+447700900321", body: "Hello", status: "queued")
    assert_nothing_raised { MessageDeliveryJob.perform_now(message.id) }
    assert_equal "failed", message.reload.status
    assert_match(/Twilio 401/, message.error)
  end

  test "twilio delivery posts the form payload" do
    Setting.set("messages_twilio_account_sid", "AC1")
    Setting.set("messages_twilio_auth_token", "t")
    Setting.set("messages_twilio_from", "+15005550006")
    stub = stub_request(:post, "https://api.twilio.com/2010-04-01/Accounts/AC1/Messages.json")
           .with(body: { "From" => "+15005550006", "To" => "+447700900321", "Body" => "Hello" })
           .to_return(status: 201, body: "{}")

    message = Message.create!(direction: "outgoing", channel: "twilio", audience: "customer",
                              to_address: "+447700900321", body: "Hello", status: "queued")
    MessageDeliveryJob.perform_now(message.id)
    assert_requested stub
    assert_equal "sent", message.reload.status
  end

  test "cleanup purges messages past the retention window" do
    Setting.set("messages_retention_days", "30")
    old_message = Message.create!(direction: "outgoing", channel: "email", to_address: "a@example.org",
                                  body: "Old", status: "sent")
    old_message.update_column(:created_at, 60.days.ago)
    Message.create!(direction: "outgoing", channel: "email", to_address: "a@example.org",
                    body: "New", status: "sent")

    result = Cleanup.run
    assert_equal 1, result[:messages_deleted]
    assert_equal [ "New" ], Message.pluck(:body)
  ensure
    Setting.set("messages_retention_days", "0")
  end

  test "cleanup keeps everything when retention is 0" do
    Message.create!(direction: "outgoing", channel: "email", to_address: "a@example.org",
                    body: "Old", status: "sent").update_column(:created_at, 900.days.ago)
    result = Cleanup.run
    assert_equal 0, result[:messages_deleted]
    assert_equal 1, Message.count
  end
end
