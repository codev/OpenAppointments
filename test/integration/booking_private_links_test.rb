require "test_helper"

# Private providers/services and hidden categories stay off the public booking
# page but become bookable through their direct slug links.
class BookingPrivateLinksTest < ActionDispatch::IntegrationTest
  DATE = "2026-07-20".freeze # Monday, see availability engine tests

  setup do
    provider_role = Role.find_by!(slug: Role::PROVIDER)

    @chair_category = ServiceCategory.create!(name: "Chair hire", is_hidden: true)
    @chair_service = Service.create!(name: "Chair rental half day", duration: 240,
                                     id_service_categories: @chair_category.id, is_private: true)
    @chair = User.create!(name: "Chair 1", email: "openouthair+chair1@example.org",
                          role: provider_role, timezone: "Europe/London", is_private: true)
    @chair.create_settings!(username: "chair1", password: Passwords.hash("chair1pass1"),
                            working_plan: user_settings(:zane).working_plan)
    ServiceProviderLink.create!(provider: @chair, service: @chair_service)

    # A second private pair that must never leak through the first pair's links.
    @other_service = Service.create!(name: "Secret Consult", duration: 30, is_private: true)
    @other_provider = User.create!(name: "Secret Pro", email: "secretpro@example.org",
                                   role: provider_role, timezone: "Europe/London", is_private: true)
    ServiceProviderLink.create!(provider: @other_provider, service: @other_service)
  end

  test "public booking page excludes private and hidden records" do
    get "/"
    assert_response :success
    assert_no_match "Chair hire", response.body
    assert_no_match "Chair rental half day", response.body
    assert_no_match "Chair 1", response.body
    assert_no_match @chair.booking_slug, response.body
    assert_no_match @chair_service.booking_slug, response.body
  end

  test "a private provider link exposes that provider and their services only" do
    get "/", params: { provider: @chair.booking_slug }
    assert_response :success
    assert_select "#select-service optgroup[label='Chair hire'] option[value=?]", @chair_service.id.to_s
    assert_match @chair.booking_slug, response.body
    assert_no_match @chair_service.booking_slug, response.body, "associated records must not expose their slugs"
    assert_no_match "Secret Consult", response.body

    get "/", params: { provider: @chair.booking_slug, step: "second", service_id: @chair_service.id }
    assert_select "#select-provider option[value=?]", @chair.id.to_s, text: "Chair 1"
    assert_no_match "Secret Pro", response.body
  end

  test "a private service link exposes the service and its providers with slugs nulled" do
    get "/", params: { service: @chair_service.booking_slug }
    assert_response :success
    assert_match "Chair rental half day", response.body
    assert_no_match @chair.booking_slug, response.body

    get "/", params: { service: @chair_service.booking_slug, step: "second", service_id: @chair_service.id }
    assert_select "#select-provider option[value=?]", @chair.id.to_s, text: "Chair 1"
    assert_no_match @chair.booking_slug, response.body
    assert_no_match "Secret Pro", response.body
  end

  test "garbage or public slugs add nothing private" do
    [ "zzzz-zzzz", services(:haircut).booking_slug ].each do |slug|
      get "/", params: { service: slug, provider: slug }
      assert_response :success
      assert_no_match "Chair 1", response.body
      assert_no_match "Secret Consult", response.body
    end
  end

  test "a private provider and service book end to end" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_includes BookingWindow.build(@chair_service, @chair.id)[DATE], "09:00"

      assert_difference "Appointment.count", 1 do
        post "/booking/register", params: {
          post_data: {
            appointment: { "start_datetime" => "#{DATE} 09:00:00",
                           "id_services" => @chair_service.id, "id_users_provider" => @chair.id },
            customer: { "name" => "Hugo Freelance", "email" => "hugo@example.org",
                        "phone_number" => "+447700900456", "timezone" => "Europe/London" },
            manage_mode: false
          }
        }
      end
      assert_response :success
      appointment = Appointment.find(response.parsed_body["appointment_id"])
      assert_equal @chair.id, appointment.id_users_provider
    end
  end

  test "any-provider never books onto a private provider" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_empty BookingWindow.build(@chair_service, "any-provider")
    end
  end

  test "cards mode renders the hidden category card only with the link" do
    Setting.set("booking_display_mode", "cards")

    get "/"
    assert_no_match "Chair hire", response.body

    get "/", params: { provider: @chair.booking_slug }
    assert_select "#category-cards .booking-card .booking-card-title", text: "Chair hire"
  end

  test "rescheduling an appointment on private records prefills them" do
    appointment = Appointment.create!(
      start_datetime: "2026-07-27 09:00:00", end_datetime: "2026-07-27 13:00:00",
      provider: @chair, customer: users(:jx), service: @chair_service, status: "Booked"
    )

    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      get "/booking/reschedule/#{appointment.booking_hash}"
    end
    assert_response :success
    assert_select "#wizard-frame-3 #select-date"
    assert_select "#wizard-frame-3 input[name=service_id][value=?]", @chair_service.id.to_s
    assert_select "#wizard-frame-3 input[name=provider_id][value=?]", @chair.id.to_s
  end
end
