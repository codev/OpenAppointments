require "test_helper"

# Waiting list signup on the time step, shown while the waitlist is enabled.
class WaitlistSignupTest < ActionDispatch::IntegrationTest
  setup do
    Setting.set("waitlist_enabled", "1")
    Setting.set("display_phone_number", "1")
    @state = { step: "time", service_id: services(:haircut).id, provider_id: users(:zane).id }
  end

  def join(extra = {})
    post "/booking/waitlist", params: @state.merge(waitlist: { name: "Waiting Person", email: "waiting@example.org", phone: "07700900001" }).deep_merge(extra)
  end

  test "the time step offers the signup only while enabled" do
    get "/booking", params: @state
    assert_select "#waitlist-form input[name='waitlist[name]']"
    assert_select "#waitlist-form input[name='waitlist[email]']"
    assert_select "#waitlist-form input[name='waitlist[phone]']"
    assert_select "#waitlist-form button", text: I18n.t("ea.waitlist_join")

    Setting.set("waitlist_enabled", "0")
    get "/booking", params: @state
    assert_select "#waitlist-form", 0
  end

  test "joining creates an entry for the chosen provider and renders the time step with a confirmation" do
    assert_difference "WaitlistEntry.count", 1 do
      join
    end
    assert_response :success
    entry = WaitlistEntry.last
    assert_equal [ "Waiting Person", "waiting@example.org", "07700900001", services(:haircut).id, users(:zane).id ],
                 [ entry.name, entry.email, entry.phone, entry.service_id, entry.provider_id ]
    assert_select "#wizard-frame-3"
    assert_select "#waitlist .alert-success", text: I18n.t("ea.waitlist_joined")
    assert_select "#waitlist-form", 0
  end

  test "any provider is stored as no provider" do
    join(provider_id: "any-provider")
    assert_nil WaitlistEntry.last.provider_id
  end

  test "joining twice for the same service is refused" do
    join
    assert_no_difference "WaitlistEntry.count" do
      join
    end
    assert_select "#waitlist .alert-warning", text: I18n.t("ea.waitlist_already_joined")
  end

  test "a missing name or bad email is refused" do
    assert_no_difference "WaitlistEntry.count" do
      join(waitlist: { name: "" })
      assert_select "#waitlist .alert-danger", text: I18n.t("ea.fields_are_required")
      join(waitlist: { email: "not-an-email" })
      assert_select "#waitlist .alert-danger", text: I18n.t("ea.invalid_email")
    end
  end

  test "disabled waitlist refuses the post" do
    Setting.set("waitlist_enabled", "0")
    join
    assert_response :forbidden
  end

  test "the waitlist strings exist in every locale" do
    keys = %w[waitlist waitlist_signup_title waitlist_signup_hint waitlist_join waitlist_joined waitlist_already_joined
              waitlist_left waitlist_link_invalid fully_booked_notice fully_booked_notice_hint fully_booked_notice_default
              notices waitlist_enabled waitlist_enabled_hint waitlist_days waitlist_days_hint waitlist_max_notices
              waitlist_max_notices_hint waitlist_min_slots waitlist_min_slots_hint waitlist_stagger_seconds
              waitlist_stagger_seconds_hint notification_event_waitlist_slot_freed notification_event_waitlist_daily
              waitlist_hint waitlist_empty waitlist_signed_up waitlist_expires waitlist_messages_sent]
    I18n.available_locales.each do |locale|
      keys.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
    end
  end
end
