require "test_helper"

# Customer Message Received: an incoming message from a known customer notifies
# the customer's stylist (next upcoming appointment, else the most recent).
class CustomerMessageNotificationsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @customer = users(:jx)
    @kai = User.create!(name: "Kai", email: "kai@example.org", role: roles(:provider), phone_number: "+447700900111")
    @notification = Notification.create!(
      title: "Customer Message Received", event: "customer_message", audiences: %w[provider],
      channels: %w[email smsgateway], short_text: "New message from {{Customer Name}}: {{Customer Message Link}}",
      long_text: "{{Customer Name}} has sent you a message.\n\nRead and reply: {{Customer Message Link}}"
    )
  end

  def incoming(customer = @customer)
    Message.create!(direction: "incoming", channel: "email", status: "received",
                    from_address: customer&.email, customer_id: customer&.id, body: "Running late")
  end

  def book(provider, start)
    Appointment.create!(start_datetime: start, end_datetime: start + 30.minutes, provider: provider,
                        customer: @customer, service: services(:haircut), status: "Booked")
  end

  test "the event is valid and has its own trigger" do
    assert_includes Notification::EVENTS, "customer_message"
    assert_equal [ @notification ], Notification.for_trigger(:customer_message).to_a
  end

  test "the token is listed and renders the login link to the customer's messages" do
    assert_includes Messaging::Template::TOKENS, "Customer Message Link"
    context = Messaging::Template.customer_message_context(customer: @customer)
    assert_match %r{\Ahttps?://.+/customers\?customer_id=#{@customer.id}&section=messages\z}, context["Customer Message Link"]
    assert_equal "JX", context["Customer Name"]
  end

  test "the stylist of the next upcoming appointment gets the email with the link" do
    book(@kai, 2.days.from_now)
    assert_enqueued_jobs 1, only: MessageDeliveryJob do
      Notifications.customer_message_received(incoming)
    end
    message = Message.outgoing.sole
    assert_equal "provider", message.audience
    assert_equal @kai.email, message.to_address
    assert_equal "email", message.channel
    assert_equal "New message from JX: #{Messaging::Template.base_url}/customers?customer_id=#{@customer.id}&section=messages", message.subject
    assert_includes message.body, "JX has sent you a message."
    assert_includes message.body, "/customers?customer_id=#{@customer.id}&section=messages"
    assert_equal @notification.id, message.notification_id
    assert_nil message.appointment_id
  end

  test "with nothing booked the most recent appointment's stylist is used" do
    book(@kai, 3.months.ago)
    book(users(:zane), 1.month.ago)
    Notifications.customer_message_received(incoming)
    assert_equal [ users(:zane).email ], Message.outgoing.pluck(:to_address)
  end

  test "the SMS goes as well once the gateway is activated" do
    book(@kai, 2.days.from_now)
    Setting.set("messages_smsgateway_enabled", "1")
    Setting.set("messages_smsgateway_url", "https://sms.example.org")
    Setting.set("messages_smsgateway_login", "user")
    Setting.set("messages_smsgateway_password", "pass")
    Notifications.customer_message_received(incoming)
    assert_equal %w[email smsgateway], Message.outgoing.order(:id).pluck(:channel)
    sms = Message.outgoing.find_by(channel: "smsgateway")
    assert_equal @kai.phone_number, sms.to_address
    assert_includes sms.body, "/customers?customer_id=#{@customer.id}&section=messages"
  ensure
    Setting.set("messages_smsgateway_enabled", "0")
  end

  test "a customer with no appointments reaches admins only when that audience is ticked" do
    solo = User.create!(name: "Solo", email: "solo@example.org", role: roles(:customer))
    Notifications.customer_message_received(incoming(solo))
    assert_equal 0, Message.outgoing.count

    @notification.update!(audiences: %w[provider admins])
    Notifications.customer_message_received(incoming(solo))
    assert_equal [ users(:admin).email ], Message.outgoing.pluck(:to_address)
  end

  test "unknown senders and disabled messaging send nothing" do
    book(@kai, 2.days.from_now)
    Notifications.customer_message_received(incoming(nil))
    assert_equal 0, Message.outgoing.count

    Setting.set("messages_enabled", "0")
    Notifications.customer_message_received(incoming)
    assert_equal 0, Message.outgoing.count
  ensure
    Setting.set("messages_enabled", "1")
  end

  test "the default set carries the template for stylists by email and SMS gateway" do
    template = Messaging::Defaults.notifications.find { |attrs| attrs[:event] == "customer_message" }
    assert_equal "Customer Message Received", template[:title]
    assert_equal %w[provider], template[:audiences]
    assert_equal %w[email smsgateway], template[:channels]
    assert_includes template[:short_text], "{{Customer Message Link}}"
    assert_includes template[:long_text], "{{Customer Message Link}}"
  end

  test "the default is added to an install that has none for the event and left alone otherwise" do
    Messaging::Defaults.create_customer_message_notification!
    assert_equal 1, Notification.where(event: "customer_message").count
    assert_equal @notification.id, Notification.where(event: "customer_message").sole.id

    @notification.destroy!
    Messaging::Defaults.create_customer_message_notification!
    assert_equal "Customer Message Received", Notification.where(event: "customer_message").sole.title
  end
end
