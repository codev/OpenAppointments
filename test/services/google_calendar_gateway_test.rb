require "test_helper"

class GoogleCalendarGatewayTest < ActiveSupport::TestCase
  setup { @gateway = GoogleCalendarGateway.new(redirect_uri: "https://app.example.org/google/oauth_callback") }

  test "build_event maps EA fields with provider-timezone datetimes" do
    event = @gateway.build_event(appointments(:upcoming), users(:zane), services(:haircut),
                                 users(:jx), "Open Out")
    assert_equal "Trim Cut", event.summary
    assert_equal "2026-07-20T10:00:00", event.start.date_time
    assert_equal "Europe/London", event.start.time_zone
    assert_equal "2026-07-20T10:30:00", event.end.date_time
    emails = event.attendees.map(&:email)
    assert_includes emails, "zane@example.org"
    assert_includes emails, "j@example.org"
  end

  test "build_event falls back to Unavailable and company name" do
    unavailability = appointments(:lunch_block)
    event = @gateway.build_event(unavailability, users(:zane), nil, nil, "Open Out")
    assert_equal "Unavailable", event.summary
    assert_equal "Open Out", event.location
    assert_equal 1, event.attendees.length
  end

  test "authorization_url includes offline access and state" do
    Setting.set("google_client_id", "cid")
    Setting.set("google_client_secret", "secret")
    url = @gateway.authorization_url(state: "xyz")
    assert_match "access_type=offline", url
    assert_match "state=xyz", url
    assert_match "max_auth_age=0", url
  end
end
