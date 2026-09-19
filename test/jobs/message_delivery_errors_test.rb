require "test_helper"
require "socket"

# A mail server that cannot be reached must leave the message failed with its
# error, never marked sent. Rails only raises delivery errors when told to, so
# every environment turns that on and the delivery job records the failure.
class MessageDeliveryErrorsTest < ActiveSupport::TestCase
  test "development and production raise delivery errors" do
    %w[development production].each do |env|
      config = Rails.root.join("config/environments/#{env}.rb").read
      assert_match(/^\s*config\.action_mailer\.raise_delivery_errors = true/, config, "#{env}.rb must raise delivery errors")
    end
  end

  test "an unreachable SMTP server marks the message failed with the error" do
    port = TCPServer.open("127.0.0.1", 0).then { |server| server.addr[1].tap { server.close } }
    saved = [ ActionMailer::Base.delivery_method, ActionMailer::Base.smtp_settings, ActionMailer::Base.raise_delivery_errors ]
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = { address: "127.0.0.1", port: port, open_timeout: 1, read_timeout: 1 }
    ActionMailer::Base.raise_delivery_errors = true
    Setting.set("messages_enabled", "1")
    Setting.set("messages_failure_alert", "0")
    message = Message.create!(channel: "email", direction: "outgoing", status: "queued",
                              to_address: "someone@example.org", subject: "Hi", body: "Hello")

    MessageDeliveryJob.perform_now(message.id)

    assert_equal "failed", message.reload.status
    assert_match(/refused|connect/i, message.error.to_s)
  ensure
    ActionMailer::Base.delivery_method, ActionMailer::Base.smtp_settings, ActionMailer::Base.raise_delivery_errors = saved
  end
end
