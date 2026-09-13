require "test_helper"

# Regressions from the booking wizard review, one case per finding.
class BookingWizardReviewTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  DATE = "2026-07-20".freeze # Monday, see availability engine tests
  HASH = "abc123def456".freeze # appointments(:upcoming), 10:00 that day

  setup do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")
    Setting.set("display_notes", "1")
    @state = { service_id: services(:haircut).id, provider_id: users(:zane).id, date: DATE, time: "11:00" }
    @customer = { name: "Review Booker", email: "review@example.org" }
  end

  def booking_time = Time.new(2026, 7, 10, 12, 0, 0)

  def confirm(extra = {})
    post "/booking/confirm", params: { form: "1", **@state, customer: @customer }.deep_merge(extra)
  end

  def register(extra = {})
    post "/booking/register", params: {
      form: "1", **@state,
      appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id, start_datetime: "#{DATE} 11:00:00" },
      customer: @customer
    }.deep_merge(extra)
  end

  def register_at_booking_time(extra = {})
    travel_to(booking_time) { register(extra) }
  end

  def private_chair
    provider_role = Role.find_by!(slug: Role::PROVIDER)
    category = ServiceCategory.create!(name: "Chair hire", is_hidden: true)
    service = Service.create!(name: "Chair rental", duration: 60, id_service_categories: category.id, is_private: true)
    chair = User.create!(name: "Chair 1", email: "chair1@example.org", role: provider_role, timezone: "Europe/London", is_private: true)
    chair.create_settings!(username: "chair1", password: Passwords.hash("chair1pass1"), working_plan: user_settings(:zane).working_plan)
    ServiceProviderLink.create!(provider: chair, service: service)
    [ chair, service ]
  end

  test "the wizard frame carries nothing Turbo would keep stale; links inside it advance history" do
    get "/"
    assert_select "turbo-frame#wizard:not([data-turbo-action]):not([data-step])"
    assert_select "a.swap-first-step[data-turbo-action=advance]"
    get "/", params: @state.merge(step: "time")
    assert_select "a#button-back-3[data-turbo-action=advance]"
  end

  test "a details step re-rendered by confirm links back into the wizard, not to the confirm route" do
    confirm(customer: { name: "" })
    assert_select "#wizard-frame-4 #form-message"
    href = css_select("a#button-back-4").first["href"]
    assert_match(%r{\A/\?}, href)
    assert_includes href, "step=time"

    confirm(manage_mode: "1", appointment_hash: HASH, customer: { name: "" })
    assert_match(%r{\A/booking/reschedule/#{HASH}\?}, css_select("a#button-back-4").first["href"])
  end

  test "confirm without a chosen slot renders the step the state reaches instead of failing" do
    post "/booking/confirm", params: { form: "1", service_id: services(:haircut).id, customer: @customer }
    assert_response :success
    assert_select "#wizard-frame-2 #select-provider"
    assert_select "#wizard-frame-5", count: 0
  end

  test "rescheduling an appointment on private records reaches the confirmation step" do
    chair, service = private_chair
    appointment = Appointment.create!(start_datetime: "#{DATE} 09:00:00", end_datetime: "#{DATE} 10:00:00",
                                      provider: chair, customer: users(:jx), service: service, status: "Booked")
    confirm(manage_mode: "1", appointment_hash: appointment.booking_hash, service_id: service.id, provider_id: chair.id)
    assert_response :success
    assert_select "#wizard-frame-5 input[name='appointment[id]'][value=?]", appointment.id.to_s
    assert_select "#wizard-frame-5 input[name='appointment_hash'][value=?]", appointment.booking_hash
    assert_select "#wizard-frame-5 #appointment-details", text: /Chair rental/
  end

  test "a slot taken meanwhile sends a reschedule back to its own time step with the link parameters" do
    travel_to booking_time do
      register(manage_mode: "1", appointment_hash: HASH, theme: "coder", provider: users(:zane).booking_slug,
               appointment: { id: appointments(:upcoming).id, start_datetime: "#{DATE} 12:00:00" }) # the lunch block
      assert_response :redirect
      location = URI(response.location)
      assert_equal "/booking/reschedule/#{HASH}", location.path
      query = Rack::Utils.parse_query(location.query)
      assert_equal "time", query["step"]
      assert_equal "coder", query["theme"]
      assert_equal users(:zane).booking_slug, query["provider"]
      assert_equal users(:zane).id.to_s, query["provider_id"]
      assert_nil query["time"]
      follow_redirect!
      assert_select "turbo-frame#wizard .alert-danger", text: I18n.t("ea.requested_hour_is_unavailable")
      assert_select "#wizard-frame-3 #select-date"
    end
    assert_equal "Booked", appointments(:upcoming).reload.status
  end

  test "notes typed in the details step are saved on the appointment" do
    confirm(customer: { notes: "Fringe only" })
    assert_select "#wizard-frame-5 input[name='appointment[notes]'][value='Fringe only']"
    assert_select "#wizard-frame-5 input[name='customer[notes]']", count: 0
    register_at_booking_time(appointment: { notes: "Fringe only" })
    assert_response :redirect
    assert_equal "Fringe only", Appointment.appointments.order(:id).last.notes
  end

  test "the Turnstile widget posts its token under the parameter name the server reads" do
    Setting.set("altcha_enabled", "1")
    Setting.set("captcha_provider", "turnstile")
    Setting.set("turnstile_site_key", "sitekey")
    Setting.set("turnstile_secret_key", "secretkey")
    confirm
    assert_select "#wizard-frame-5 .cf-turnstile[data-response-field-name=cf_turnstile_response]"
    Setting.set("captcha_login_enabled", "1")
    get "/login"
    assert_select ".cf-turnstile[data-response-field-name=cf_turnstile_response]"
  end

  # The test cache is a null store; the customer token must survive between requests.
  def with_memory_cache
    store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = store
  end

  test "the reschedule page has the cancellation reason and personal data deletion forms" do
    Setting.set("display_delete_personal_information", "1")
    customer_id = users(:jx).id
    with_memory_cache do
      travel_to booking_time do # the token expires ten minutes after the page
        get "/booking/reschedule/#{HASH}"
        assert_select "#cancel-appointment-modal form[action='/booking_cancellation/of/#{HASH}'] textarea[name=cancellation_reason][required]"
        assert_select "#cancel-appointment[data-bs-target='#cancel-appointment-modal']"
        token = css_select("#delete-personal-information-form input[name=customer_token]").first["value"]
        assert_match(/\A[a-f0-9]{32}\z/, token)
        assert_no_match token, response.body[/const vars = (.*);/, 1]

        post "/privacy/delete_personal_information", params: { form: "1", customer_token: token }
        assert_redirected_to "/"
      end
    end
    assert_nil User.find_by(id: customer_id)
    assert_nil Appointment.find_by(booking_hash: HASH)
  end

  test "a reschedule must name the appointment that matches its hash" do
    other = Appointment.create!(start_datetime: "#{DATE} 14:00:00", end_datetime: "#{DATE} 14:30:00",
                                provider: users(:zane), customer: users(:jx), service: services(:haircut), status: "Booked")
    assert_no_difference "Appointment.count" do
      register_at_booking_time(manage_mode: "1", appointment_hash: HASH, appointment: { id: other.id })
    end
    assert_response :success
    assert_select "#wizard-frame-5 #form-message", text: I18n.t("ea.appointment_does_not_exist_in_db")
    assert_equal "Booked", other.reload.status
    assert_equal "Booked", appointments(:upcoming).reload.status
  end

  test "a reschedule without an email keeps the appointment's customer" do
    customer = User.create!(name: "Phone Only", phone_number: "+447700900999", role: Role.find_by!(slug: Role::CUSTOMER))
    appointment = Appointment.create!(start_datetime: "#{DATE} 14:00:00", end_datetime: "#{DATE} 14:30:00",
                                      provider: users(:zane), customer: customer, service: services(:haircut), status: "Booked")
    @customer = { name: "Phone Only", phone_number: "+447700900999" }
    assert_no_difference "User.customers.count" do
      register_at_booking_time(manage_mode: "1", appointment_hash: appointment.booking_hash, appointment: { id: appointment.id })
    end
    assert_response :redirect
    assert_equal customer.id, appointment.reload.rescheduled_to.id_users_customer
  end

  test "the customer timezone comes from the time step, else the provider's" do
    Setting.set("fixed_timezone", "0")
    confirm(timezone: "America/New_York")
    assert_select "#wizard-frame-5 input[name='customer[timezone]'][value='America/New_York']"
    assert_select "#wizard-frame-5 #appointment-details", text: /6:00 am/ # 11:00 in London
    register_at_booking_time(customer: { timezone: "America/New_York" })
    assert_equal "America/New_York", User.customers.find_by!(email: "review@example.org").timezone

    confirm(timezone: "Not/AZone")
    assert_select "#wizard-frame-5 input[name='customer[timezone]'][value='Europe/London']"
    assert_select "#wizard-frame-5 #appointment-details", text: /11:00 am/
    register_at_booking_time(customer: { email: "second@example.org" }, appointment: { start_datetime: "#{DATE} 11:30:00" })
    assert_equal "Europe/London", User.customers.find_by!(email: "second@example.org").timezone
  end

  test "the header shows the choices so far, ticks completed steps and links them back" do
    get "/"
    assert_select ".display-booking-selection", text: "Service"
    assert_select "#steps #step-1.active-step[data-tippy-content]"
    assert_select "#steps .completed-step", count: 0

    get "/", params: { step: "second", service_id: services(:haircut).id }
    assert_select ".display-booking-selection", text: "#{services(:haircut).name} │ Provider"
    assert_select "#steps #step-1.completed-step[role=button][data-href^='/?']"
    assert_select "#steps #step-2.active-step"
    assert_select "turbo-frame#wizard #wizard-state[data-step='2'][data-step-links]"

    get "/", params: { first: "provider" }
    assert_select ".display-booking-selection", text: "Provider"

    get "/", params: { provider: users(:zane).booking_slug }
    assert_select ".display-booking-selection", text: "Service │ Zane"

    get "/", params: @state.merge(step: "time")
    assert_select ".display-booking-selection", text: "#{services(:haircut).name} │ Zane"
    assert_select "#steps #step-2.completed-step[data-href*='step=second']"
    assert_select "#steps #step-3.active-step"
  end

  test "the time step names the provider zone and carries the chosen zone" do
    Setting.set("fixed_timezone", "0")
    get "/", params: @state.merge(step: "time", timezone: "America/New_York")
    assert_select "#wizard-frame-3[data-provider-timezone='Europe/London'][data-selected-timezone='America/New_York']"
    assert_select "#wizard-frame-3 select#select-timezone[name=timezone]"
    assert_select "#wizard-frame-3[data-appointment-start]", count: 0

    Setting.set("fixed_timezone", "1")
    get "/", params: @state.merge(step: "time", timezone: "America/New_York")
    assert_select "#wizard-frame-3 select#select-timezone[disabled]"
    confirm(timezone: "America/New_York")
    assert_select "#wizard-frame-5 input[name='customer[timezone]'][value=?]", Setting.get("default_timezone", "UTC")
  end
end
