require "test_helper"

class NotificationsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @appointment = appointments(:upcoming)
    @service = services(:haircut)
    @provider = users(:zane)
    @customer = users(:jx)
    @settings = { company_name: "Test Company", company_link: "https://example.org",
                  company_email: "info@example.org", company_color: nil,
                  date_format: "DMY", time_format: "regular" }
  end

  test "saved notifies customer, provider and admin" do
    # customer (jx, has email + customer_notifications=1), provider (zane,
    # notifications on), admin (administrator, notifications on) = 3 emails.
    assert_enqueued_emails 3 do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer, @settings)
    end
  end

  test "customer_notifications=0 silences customer email" do
    Setting.set("customer_notifications", "0")
    assert_enqueued_emails 2 do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer, @settings)
    end
  ensure
    Setting.set("customer_notifications", "1")
  end

  test "provider notifications flag honored" do
    user_settings(:zane).update!(notifications: false)
    assert_enqueued_emails 2 do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer, @settings)
    end
  end

  test "secretary notified only when linked to the provider" do
    secretary = users(:sam)
    secretary.create_settings!(username: "sams", password: Passwords.hash("secret77"), notifications: true)

    assert_enqueued_emails 3 do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer, @settings)
    end

    SecretaryProviderLink.create!(id_users_secretary: secretary.id, id_users_provider: @provider.id)
    assert_enqueued_emails 4 do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer, @settings)
    end
  end

  test "deleted notifies same recipients" do
    assert_enqueued_emails 3 do
      Notifications.appointment_deleted(@appointment, @service, @provider, @customer, @settings,
                                        reason: "Closed")
    end
  end

  test "mailer failure does not raise" do
    # ActionMailer resolves .saved via method_missing, so a raising singleton shadows it.
    AppointmentMailer.define_singleton_method(:saved) { |**| raise "boom" }
    assert_nothing_raised do
      Notifications.appointment_saved(@appointment, @service, @provider, @customer, @settings)
    end
  ensure
    AppointmentMailer.singleton_class.remove_method(:saved)
  end
end
