require "test_helper"

class PhoneOrEmailTest < ActionDispatch::IntegrationTest
  DATE = "2026-07-20".freeze

  def register_params(customer)
    {
      post_data: {
        appointment: {
          "start_datetime" => "#{DATE} 11:00:00",
          "id_services" => services(:haircut).id, "id_users_provider" => users(:zane).id
        },
        customer: customer,
        manage_mode: false
      }
    }
  end

  def register(customer)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/booking/register", params: register_params(customer)
    end
  end

  test "phone only books when phone-or-email is on (default)" do
    assert_difference "Appointment.count", 1 do
      register("name" => "Phone Only", "phone_number" => "+447700900444")
    end
    assert_response :success
    customer = User.customers.find_by(name: "Phone Only")
    assert_equal "", customer.email.to_s
    assert customer.phone_number.present?
  end

  test "email only books" do
    assert_difference "Appointment.count", 1 do
      register("name" => "Email Only", "email" => "emailonly@example.org")
    end
    assert_response :success
  end

  test "neither phone nor email is rejected" do
    assert_no_difference "Appointment.count" do
      register("name" => "No Contact")
    end
    body = response.parsed_body
    assert_equal false, body["success"]
    assert_equal I18n.t("ea.phone_or_email_required"), body["message"]
  end

  test "turning the setting off skips the OR enforcement (legacy behaviour)" do
    Setting.set("require_phone_or_email", "0")
    assert_difference "Appointment.count", 1 do
      register("name" => "Old Rules")
    end
    assert_response :success
  end

  test "the OR rule relaxes the two require flags on the details step" do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")
    Setting.set("require_email", "1")
    Setting.set("require_phone_number", "1")

    get "/", params: { step: "info", service_id: services(:haircut).id, provider_id: users(:zane).id, date: "2026-07-20", time: "10:00" }
    assert_select "#email:not([required])"
    assert_select "#phone-number:not([required])"
    assert_select "label[for=email] .required-either"

    Setting.set("require_phone_or_email", "0")
    get "/", params: { step: "info", service_id: services(:haircut).id, provider_id: users(:zane).id, date: "2026-07-20", time: "10:00" }
    assert_select "#email[required]"
    assert_select "#phone-number[required]"
  end

  test "booking page marks email and phone with the half asterisk when either is enough" do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")

    get "/", params: { step: "info", service_id: services(:haircut).id, provider_id: users(:zane).id, date: "2026-07-20", time: "10:00" }
    assert_select "label[for=email] .required-either", text: "*"
    assert_select "label[for=phone-number] .required-either", text: "*"
    assert_select "label[for=email] .visually-hidden", text: I18n.t("ea.phone_or_email_required")

    Setting.set("require_phone_or_email", "0")
    get "/", params: { step: "info", service_id: services(:haircut).id, provider_id: users(:zane).id, date: "2026-07-20", time: "10:00" }
    assert_select ".required-either", false
  end

  test "no customer email means no customer mail and no crash" do
    Setting.set("customer_notifications", "1")
    UserSetting.update_all(notifications: false)
    assert_no_enqueued_emails do
      register("name" => "Phone Only Two", "phone_number" => "+447700900446")
    end
    assert_response :success
  end

  test "the details step shows the phone-or-email message when both are blank" do
    post "/booking/confirm", params: { form: "1", step: "info", service_id: services(:haircut).id,
                                       provider_id: users(:zane).id, date: "2026-07-20", time: "10:00",
                                       customer: { name: "Only Name" } }
    assert_select "#wizard-frame-4 #form-message[data-tone=error]", text: I18n.t("ea.phone_or_email_required")
    assert_select "#name[value='Only Name']"
  end

  test "seeds do not require email or phone individually" do
    seeds = Rails.root.join("db/seeds.rb").read
    assert_match(/"require_email" => "0"/, seeds)
    assert_match(/"require_phone_number" => "0"/, seeds)
  end

  test "settings save clears individual require flags while the OR rule is on" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    post "/booking_settings/save", params: {
      booking_settings: [
        { name: "require_phone_or_email", value: "1" },
        { name: "require_email", value: "1" },
        { name: "require_phone_number", value: "1" }
      ]
    }
    assert_response :success
    assert_equal "0", Setting.get("require_email")
    assert_equal "0", Setting.get("require_phone_number")
  end

  test "settings save keeps require flags when the OR rule is off" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    post "/booking_settings/save", params: {
      booking_settings: [
        { name: "require_phone_or_email", value: "0" },
        { name: "require_email", value: "1" }
      ]
    }
    assert_response :success
    assert_equal "1", Setting.get("require_email")
  end

  test "migration clears stored require flags where the OR rule is on" do
    migration = Rails.root.glob("db/migrate/*_relax_contact_require_flags.rb").first
    require migration
    Setting.set("require_email", "1")
    Setting.set("require_phone_number", "1")
    ActiveRecord::Migration.suppress_messages { RelaxContactRequireFlags.new.up }
    assert_equal "0", Setting.get("require_email")

    Setting.set("require_phone_or_email", "0")
    Setting.set("require_email", "1")
    ActiveRecord::Migration.suppress_messages { RelaxContactRequireFlags.new.up }
    assert_equal "1", Setting.get("require_email")
  end

  test "the new strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[phone_or_email_required require_phone_or_email_label].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
