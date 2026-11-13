require "test_helper"

# Booking Notices: one rich text block per booking step, edited on the Notices
# page and shown on its step whenever it has content. The service, provider and
# confirmation notices sit above the step's buttons; the time and details steps
# carry theirs under the heading.
class BookingNoticeTest < ActionDispatch::IntegrationTest
  STEPS = %w[service provider time info final].freeze
  DATE = "2026-07-20".freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def state
    { service_id: services(:haircut).id, provider_id: users(:zane).id }
  end

  def service_step = get("/", params: { step: "first" })
  def provider_step = get("/", params: { step: "second", service_id: services(:haircut).id })
  def time_step = get("/", params: { step: "time", **state })
  def info_step = get("/", params: { step: "info", **state, date: DATE, time: "10:00" })

  def final_step
    post "/booking/confirm", params: { form: "1", **state, date: DATE, time: "10:00",
                                       customer: { name: "Notice Reader", email: "reader@example.org" } }
  end

  def set_all_notices
    STEPS.each { |step| Setting.set("booking_notice_#{step}_content", "<p>Notice for #{step}.</p>") }
  end

  def assert_only_notice(frame, step)
    assert_select "#wizard-frame-#{frame} div.booking-notice:not(.alert) p", text: "Notice for #{step}."
    assert_select "div.booking-notice", count: 1
  end

  test "the Notices page has one box per step, no switches, above the cookie notice" do
    login_admin
    get "/legal_settings"
    assert_response :success
    STEPS.each do |step|
      assert_select "textarea#booking-notice-#{step}-content[name='settings[booking_notice_#{step}_content]']"
    end
    assert_select "[name='settings[display_booking_notice_time_step]']", 0
    assert_select "[name='settings[display_booking_notice_info_step]']", 0
    assert_select "textarea#booking-notice-content", 0
    positions = STEPS.map { |step| response.body.index("booking-notice-#{step}-content") }
    assert_equal positions.sort, positions
    assert_operator positions.last, :<, response.body.index("cookie-notice-content")
  end

  test "saving the Notices page stores each notice sanitised" do
    login_admin
    post "/legal_settings/save", params: { settings: {
      booking_notice_service_content: "<p>Pick one.</p><script>alert(1)</script>",
      booking_notice_final_content: '<p style="text-align: center; background: url(javascript:x)">Centred</p>'
    } }
    assert_equal "<p>Pick one.</p>alert(1)", Setting.get("booking_notice_service_content")
    assert_equal '<p style="text-align:center;">Centred</p>', Setting.get("booking_notice_final_content")
  end

  test "no notice shows while the boxes are empty" do
    STEPS.each { |step| Setting.set("booking_notice_#{step}_content", "") }
    service_step
    assert_select ".booking-notice", 0
    provider_step
    assert_select ".booking-notice", 0
    time_step
    assert_select ".booking-notice", 0
    info_step
    assert_select ".booking-notice", 0
    final_step
    assert_select ".booking-notice", 0
  end

  test "the service step shows its notice above the buttons" do
    set_all_notices
    service_step
    assert_only_notice(1, "service")
    assert_operator response.body.index("booking-notice"), :>, response.body.index('id="select-service"')
    assert_operator response.body.index("booking-notice"), :<, response.body.index("command-buttons")
  end

  test "the provider step shows its notice above the buttons" do
    set_all_notices
    provider_step
    assert_only_notice(2, "provider")
    assert_operator response.body.index("booking-notice"), :>, response.body.index('id="select-provider"')
    assert_operator response.body.index("booking-notice"), :<, response.body.index("command-buttons")
  end

  test "the time step shows its notice above the calendar" do
    set_all_notices
    time_step
    assert_only_notice(3, "time")
    assert_operator response.body.index("booking-notice"), :<, response.body.index('id="select-date"')
  end

  test "the details step shows its notice above the customer fields" do
    set_all_notices
    info_step
    assert_only_notice(4, "info")
    assert_operator response.body.index("booking-notice"), :<, response.body.index('id="name"')
  end

  test "the confirmation step shows its notice above the buttons" do
    set_all_notices
    final_step
    assert_only_notice(5, "final")
    assert_operator response.body.index("booking-notice"), :>, response.body.index('id="appointment-details"')
    assert_operator response.body.index("booking-notice"), :<, response.body.index("command-buttons")
  end

  test "the booking notice keys exist in every locale and the old ones are gone" do
    keys = %w[booking_notice booking_notice_service booking_notice_provider booking_notice_time_step
              booking_notice_info_step booking_notice_final_step booking_notice_hint]
    gone = %w[display_booking_notice_time_step display_booking_notice_info_step booking_notice_content]
    I18n.available_locales.each do |locale|
      keys.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
      gone.each do |key|
        assert_nil I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil), "stale ea.#{key} in #{locale}"
      end
    end
  end

  test "the message templates no longer offer a Booking Notice token" do
    assert_not_includes Messaging::Template::TOKENS, "Booking Notice"
    assert_equal "", Messaging::Template.render("{{Booking Notice}}", Messaging::Template.base_context)
  end
end
