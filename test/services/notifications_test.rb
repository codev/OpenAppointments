require "test_helper"

class NotificationsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @appointment = appointments(:upcoming)
    @service = services(:haircut)
    @provider = users(:zane)
    @customer = users(:jx)
  end

  def create_notification(**attrs)
    Notification.create!({
      title: "Saved", event: "created_or_updated", audiences: %w[customer provider admins],
      channels: %w[email], short_text: "Saved: {{Service Name}}",
      long_text: "Hello {{Customer Name}}, {{Appointment Date}} at {{Appointment Time}}. {{Appointment Link}}"
    }.merge(attrs))
  end

  test "saved fans out to customer, provider and admins over email" do
    create_notification
    assert_enqueued_jobs 3, only: MessageDeliveryJob do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer)
    end
    assert_equal %w[admins customer provider], Message.pluck(:audience).sort
    customer_message = Message.find_by(audience: "customer")
    assert_equal @customer.id, customer_message.customer_id
    assert_equal @customer.email, customer_message.to_address
    assert_includes customer_message.body, "Hello JX"
    assert_includes customer_message.body, "/booking/reschedule/#{@appointment.booking_hash}"
    assert_equal "Saved: Trim Cut", customer_message.subject
    provider_message = Message.find_by(audience: "provider")
    assert_nil provider_message.customer_id
    assert_includes provider_message.body, "/calendar/reschedule/#{@appointment.booking_hash}"
  end

  test "messages_enabled=0 silences all notifications" do
    create_notification
    Setting.set("messages_enabled", "0")
    assert_no_enqueued_jobs only: MessageDeliveryJob do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer)
    end
  ensure
    Setting.set("messages_enabled", "1")
  end

  test "event matching: created template does not fire for updates" do
    create_notification(event: "created", audiences: %w[customer])
    assert_no_enqueued_jobs only: MessageDeliveryJob do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer, manage_mode: true)
    end
    assert_enqueued_jobs 1, only: MessageDeliveryJob do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer, manage_mode: false)
    end
  end

  test "status change to Cancelled fires cancelled instead of updated" do
    create_notification(event: "cancelled", audiences: %w[customer], title: "Bye")
    create_notification(event: "created_or_updated", audiences: %w[customer], title: "Saved")
    @appointment.status = "Cancelled"
    Notifications.appointment_saved(@appointment, @service, @provider, @customer,
                                    manage_mode: true, previous_status: "Booked")
    assert_equal [ "Bye" ], Message.all.map { |m| m.notification.title }
  end

  test "status change to No Show fires missed" do
    create_notification(event: "missed", audiences: %w[customer], title: "Missed")
    @appointment.status = "No Show"
    Notifications.appointment_saved(@appointment, @service, @provider, @customer,
                                    manage_mode: true, previous_status: "Booked")
    assert_equal [ "Missed" ], Message.all.map { |m| m.notification.title }
  end

  test "deleted fires cancelled with the reason token" do
    create_notification(event: "cancelled", audiences: %w[customer],
                        long_text: "Cancelled because {{Cancellation Reason}}")
    Notifications.appointment_deleted(@appointment, @service, @provider, @customer, reason: "Closed")
    assert_includes Message.sole.body, "Cancelled because Closed"
  end

  test "secretaries are notified only when linked to the provider" do
    create_notification(audiences: %w[admins])
    Notifications.appointment_saved(@appointment, @service, @provider, @customer)
    assert_equal 1, Message.count # admin only

    SecretaryProviderLink.create!(id_users_secretary: users(:sam).id, id_users_provider: @provider.id)
    Message.delete_all
    Notifications.appointment_saved(@appointment, @service, @provider, @customer)
    assert_equal 2, Message.count
  end

  test "do_not_contact customers are skipped" do
    create_notification(audiences: %w[customer])
    @customer.update!(notes: "do_not_contact=yes")
    assert_no_enqueued_jobs only: MessageDeliveryJob do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer)
    end
  end

  test "sms channels use the short text and need a phone number" do
    Setting.set("messages_twilio_enabled", "1")
    Setting.set("messages_twilio_account_sid", "AC1")
    Setting.set("messages_twilio_auth_token", "t")
    Setting.set("messages_twilio_from", "+15005550006")
    create_notification(audiences: %w[customer provider], channels: %w[twilio])

    Notifications.appointment_saved(@appointment, @service, @provider, @customer)
    # provider zane has no phone number, so only the customer gets an SMS
    message = Message.sole
    assert_equal "twilio", message.channel
    assert_equal "+447700900321", message.to_address
    assert_equal "Saved: Trim Cut", message.body
    assert_nil message.subject
  ensure
    Setting.set("messages_twilio_enabled", "0")
  end

  test "disabled channels are not used even when ticked" do
    create_notification(audiences: %w[customer], channels: %w[twilio])
    assert_no_enqueued_jobs only: MessageDeliveryJob do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer)
    end
  end

  test "recipient failure does not raise or block other recipients" do
    create_notification
    Message.define_singleton_method(:create!) { |*| raise "boom" }
    assert_nothing_raised do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer)
    end
  ensure
    Message.singleton_class.remove_method(:create!)
  end

  test "scan_coming_up before mode sends once and again after reschedule" do
    notification = create_notification(event: "coming_up", lead_mode: "before",
                                       lead_days: 0, lead_hours: 2, audiences: %w[customer])
    start_at = Time.zone.parse("2026-08-01 15:00")
    appointment = Appointment.create!(provider: @provider, customer: @customer, service: @service,
                                      start_datetime: start_at, end_datetime: start_at + 30.minutes,
                                      status: "Booked")

    Notifications.scan_coming_up(Time.zone.parse("2026-08-01 12:00"))
    assert_equal 0, Message.count # not due yet

    Notifications.scan_coming_up(Time.zone.parse("2026-08-01 13:30"))
    assert_equal 1, Message.count
    assert_equal notification.id, Message.sole.notification_id

    Notifications.scan_coming_up(Time.zone.parse("2026-08-01 13:45"))
    assert_equal 1, Message.count # deduped

    appointment.update!(start_datetime: start_at + 1.day, end_datetime: start_at + 1.day + 30.minutes)
    Notifications.scan_coming_up(Time.zone.parse("2026-08-02 14:00"))
    assert_equal 2, Message.count # new start, reminder sent again
  end

  test "scan_coming_up day_at mode sends at the configured morning time" do
    create_notification(event: "coming_up", lead_mode: "day_at", lead_days: 0,
                        send_time: "08:00", audiences: %w[customer])
    start_at = Time.zone.parse("2026-08-01 15:00")
    Appointment.create!(provider: @provider, customer: @customer, service: @service,
                        start_datetime: start_at, end_datetime: start_at + 30.minutes,
                        status: "Booked")

    Notifications.scan_coming_up(Time.zone.parse("2026-08-01 07:30"))
    assert_equal 0, Message.count

    Notifications.scan_coming_up(Time.zone.parse("2026-08-01 08:05"))
    assert_equal 1, Message.count
  end

  test "scan_coming_up skips cancelled appointments" do
    create_notification(event: "coming_up", lead_mode: "before", lead_days: 0,
                        lead_hours: 2, audiences: %w[customer])
    start_at = Time.zone.parse("2026-08-01 15:00")
    Appointment.create!(provider: @provider, customer: @customer, service: @service,
                        start_datetime: start_at, end_datetime: start_at + 30.minutes,
                        status: "Cancelled")

    Notifications.scan_coming_up(Time.zone.parse("2026-08-01 14:00"))
    assert_equal 0, Message.count
  end
end
