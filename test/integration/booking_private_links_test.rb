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
    assert_match "Chair 1", response.body
    assert_match "Chair rental half day", response.body
    assert_match @chair.booking_slug, response.body

    provider_row = script_var("available_providers").find { |row| row["id"] == @chair.id }
    assert provider_row["is_private"]

    service_row = script_var("available_services").find { |row| row["id"] == @chair_service.id }
    assert_equal "Chair hire", service_row["service_category_name"]
    assert_nil service_row["booking_slug"], "associated records must not expose their slugs"

    assert_no_match "Secret Consult", response.body
    assert_no_match "Secret Pro", response.body
  end

  test "a private service link exposes the service and its providers with slugs nulled" do
    get "/", params: { service: @chair_service.booking_slug }
    assert_response :success
    assert_match "Chair rental half day", response.body
    assert_match "Chair 1", response.body
    assert_no_match @chair.booking_slug, response.body

    provider_row = script_var("available_providers").find { |row| row["id"] == @chair.id }
    assert_nil provider_row["booking_slug"]
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
      post "/booking/get_available_hours", params: {
        service_id: @chair_service.id, provider_id: @chair.id,
        selected_date: DATE, service_duration: 240, manage_mode: 0, appointment_id: ""
      }
      assert_response :success
      assert_includes response.parsed_body, "09:00"

      get "/booking/get_unavailable_dates", params: {
        provider_id: @chair.id, service_id: @chair_service.id,
        selected_date: DATE, manage_mode: 0
      }
      assert_response :success
      assert_not_includes response.parsed_body, DATE

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
      post "/booking/get_available_hours", params: {
        service_id: @chair_service.id, provider_id: "any-provider",
        selected_date: DATE, manage_mode: 0
      }
      assert_equal [], response.parsed_body
    end
  end

  test "cards mode renders the hidden category card only with the link" do
    Setting.set("booking_display_mode", "cards")

    get "/"
    assert_no_match "Chair hire", response.body

    get "/", params: { provider: @chair.booking_slug }
    assert_select "#category-cards .booking-card .card-title", text: "Chair hire"
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
    assert(script_var("available_services").any? { |row| row["id"] == @chair_service.id })
    assert(script_var("available_providers").any? { |row| row["id"] == @chair.id })
  end

  private

  # The wizard's window.vars payload rendered into the booking page.
  def script_var(name)
    json = response.body[/const vars = (.*);/, 1]
    assert json, "script vars not found in the booking page body"
    JSON.parse(json)[name]
  end
end
