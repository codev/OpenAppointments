require "test_helper"

# Booking Notice: a rich text block edited on the Legal Contents page, shown on
# the date/time and customer details steps when their switches are on, and
# available to notification templates as {{Booking Notice}}.
class BookingNoticeTest < ActionDispatch::IntegrationTest
  NOTICE = "<p>Please arrive five minutes early.</p>".freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def time_step
    get "/", params: { step: "time", service_id: services(:haircut).id, provider_id: users(:zane).id }
  end

  def info_step
    get "/", params: { step: "info", service_id: services(:haircut).id, provider_id: users(:zane).id,
                       date: "2026-07-20", time: "10:00" }
  end

  test "legal contents page shows the booking notice block above the cookie notice" do
    login_admin
    get "/legal_settings"
    assert_response :success
    assert_select "#display-booking-notice-time-step[name='settings[display_booking_notice_time_step]']"
    assert_select "#display-booking-notice-info-step[name='settings[display_booking_notice_info_step]']"
    assert_select "textarea#booking-notice-content[name='settings[booking_notice_content]']"
    assert_operator response.body.index("booking-notice-content"), :<, response.body.index("cookie-notice-content")
    assert_operator response.body.index("display-booking-notice-time-step"), :<, response.body.index("booking-notice-content")
  end

  test "saving the legal contents page stores the switches and the sanitised notice" do
    login_admin
    post "/legal_settings/save", params: { settings: {
      display_booking_notice_time_step: "1", display_booking_notice_info_step: "0",
      booking_notice_content: "#{NOTICE}<script>alert(1)</script>"
    } }
    assert_equal "1", Setting.get("display_booking_notice_time_step")
    assert_equal "0", Setting.get("display_booking_notice_info_step")
    assert_equal "#{NOTICE}alert(1)", Setting.get("booking_notice_content")
  end

  test "saving keeps the editor's text alignment and drops unsafe styles" do
    login_admin
    post "/legal_settings/save", params: { settings: {
      booking_notice_content: '<p style="text-align: center; background: url(javascript:x)">Centred</p>'
    } }
    assert_equal '<p style="text-align:center;">Centred</p>', Setting.get("booking_notice_content")
  end

  test "the notice is absent from both steps while the switches are off" do
    Setting.set("booking_notice_content", NOTICE)
    time_step
    assert_select ".booking-notice", 0
    info_step
    assert_select ".booking-notice", 0
  end

  test "the time step shows the notice above the calendar when its switch is on" do
    Setting.set("booking_notice_content", NOTICE)
    Setting.set("display_booking_notice_time_step", "1")
    time_step
    assert_select "#wizard-frame-3 div.booking-notice:not(.alert) p", text: "Please arrive five minutes early."
    assert_operator response.body.index("booking-notice"), :<, response.body.index('id="select-date"')
    info_step
    assert_select ".booking-notice", 0
  end

  test "the details step shows the notice above the customer fields when its switch is on" do
    Setting.set("booking_notice_content", NOTICE)
    Setting.set("display_booking_notice_info_step", "1")
    info_step
    assert_select "#wizard-frame-4 div.booking-notice:not(.alert) p", text: "Please arrive five minutes early."
    assert_operator response.body.index("booking-notice"), :<, response.body.index('id="name"')
    time_step
    assert_select ".booking-notice", 0
  end

  test "the booking notice keys exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[booking_notice display_booking_notice_time_step display_booking_notice_info_step booking_notice_content].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
    end
  end
end
