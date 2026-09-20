require "test_helper"

# One way calendar feed: a provider's appointments and unavailabilities as an
# ICS calendar behind a secret link that calendar apps subscribe to.
class CalendarFeedTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def login(username, password)
    post "/login/validate", params: { username: username, password: password }
  end

  def feed_link(provider_id, reset: nil)
    post "/calendar/feed_link", params: { provider_id: provider_id, reset: reset }.compact, as: :json
    response.parsed_body["url"]
  end

  test "the feed lists booked appointments and unavailabilities in the window, not cancelled ones" do
    zane = users(:zane)
    zane.settings.update!(calendar_feed_token: "a" * 32)
    lunch = Appointment.create!(provider: zane, is_unavailability: true, notes: "Lunch",
                                start_datetime: Time.new(2026, 7, 21, 13, 0, 0), end_datetime: Time.new(2026, 7, 21, 14, 0, 0))
    cancelled = Appointment.create!(provider: zane, customer: users(:jx), service: services(:haircut), status: "Cancelled",
                                    start_datetime: Time.new(2026, 7, 22, 11, 0, 0), end_datetime: Time.new(2026, 7, 22, 11, 30, 0))
    old = Appointment.create!(provider: zane, customer: users(:jx), service: services(:haircut), status: "Booked",
                              start_datetime: Time.new(2026, 5, 1, 11, 0, 0), end_datetime: Time.new(2026, 5, 1, 11, 30, 0))

    travel_to(Time.new(2026, 7, 10, 12, 0, 0)) { get "/calendar/feed/#{'a' * 32}.ics" }
    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_match(/no-cache/, response.headers["Cache-Control"])
    body = response.body
    assert_includes body, "X-WR-CALNAME:"
    assert_includes body, "SUMMARY:Trim Cut - JX"
    assert_includes body, "DTSTART;TZID=Europe/London:20260720T100000"
    assert_includes body, "UID:#{IcsFile.uid_for(appointments(:upcoming).id)}"
    assert_includes body, "/calendar/reschedule/#{appointments(:upcoming).booking_hash}"
    assert_includes body, "SUMMARY:Lunch"
    assert_includes body, "UID:#{IcsFile.uid_for(lunch.id)}"
    assert_not_includes body, IcsFile.uid_for(cancelled.id)
    assert_not_includes body, IcsFile.uid_for(old.id)
    assert_not_includes body, "j@example.org"
  end

  test "an unknown or missing token is not found" do
    get "/calendar/feed/nope.ics"
    assert_response :not_found
  end

  test "the link is made on first request, kept, and remade on reset" do
    login("administrator", "administrator1")
    first = feed_link(users(:zane).id)
    assert_match %r{\Ahttp://www\.example\.com/calendar/feed/[A-Za-z0-9]{32}\.ics\z}, first
    assert_equal first, feed_link(users(:zane).id)
    reset = feed_link(users(:zane).id, reset: "1")
    assert_not_equal first, reset
    assert_equal reset.split("/").last.delete_suffix(".ics"), users(:zane).settings.reload.calendar_feed_token

    get "/calendar/feed/#{first.split('/').last}"
    assert_response :not_found
    get "/calendar/feed/#{reset.split('/').last}"
    assert_response :success
  end

  test "a provider gets their own link but not another provider's, and a visitor gets nothing" do
    other = User.create!(name: "Other", email: "other@example.org", role: roles(:provider))
    login("janedoe", "janedoe1")
    assert_match "/calendar/feed/", feed_link(users(:zane).id)
    post "/calendar/feed_link", params: { provider_id: other.id }, as: :json
    assert_response :forbidden

    reset!
    post "/calendar/feed_link", params: { provider_id: users(:zane).id }, as: :json
    assert_response :unauthorized
  end
end
