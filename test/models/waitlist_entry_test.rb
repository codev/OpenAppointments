require "test_helper"

# A waitlist entry lives for waitlist_days, is matched against freed slots by
# duration and by the provider offering the wanted service, and stops getting
# freed-slot notices at waitlist_max_notices.
class WaitlistEntryTest < ActiveSupport::TestCase
  def sign_up(service: services(:haircut), provider: nil, **attrs)
    WaitlistEntry.create!({ name: "Waiting Person", email: "waiting@example.org", service: service,
                            provider: provider }.merge(attrs))
  end

  test "signing up copies the service duration, sets the expiry and an unsubscribe token" do
    Setting.set("waitlist_days", "10")
    entry = sign_up
    assert_equal 30, entry.duration
    assert_in_delta 10.days.from_now, entry.expires_at, 5
    assert_match(/\A[A-Za-z0-9]{24}\z/, entry.unsubscribe_token)
    assert_equal 0, entry.notices_sent
  end

  test "live entries are those not yet expired" do
    live = sign_up
    expired = sign_up(expires_at: 1.minute.ago)
    assert_includes WaitlistEntry.live, live
    assert_not_includes WaitlistEntry.live, expired
  end

  test "a freed slot matches by length and by the provider offering the wanted service, longest waiting first" do
    later = sign_up(email: "later@example.org", created_at: 1.hour.ago)
    earlier = sign_up(email: "earlier@example.org", created_at: 2.hours.ago)
    longer = sign_up(service: services(:group_session))
    other_provider = sign_up(provider: User.create!(name: "Other", email: "other@example.org", role: roles(:provider)))
    zane_only = sign_up(provider: users(:zane))
    capped = sign_up(email: "capped@example.org", notices_sent: 7)
    expired = sign_up(email: "expired@example.org", expires_at: 1.minute.ago)

    matched = WaitlistEntry.for_freed_slot(users(:zane), 45)
    assert_equal [ earlier, later, zane_only ], matched
    [ longer, other_provider, capped, expired ].each { |entry| assert_not_includes matched, entry }

    assert_includes WaitlistEntry.for_freed_slot(users(:zane), 60), longer
  end

  test "notices stop at the configured maximum" do
    Setting.set("waitlist_max_notices", "2")
    entry = sign_up(notices_sent: 1)
    assert entry.notices_left?
    entry.update!(notices_sent: 2)
    assert_not entry.notices_left?
  end
end
