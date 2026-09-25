require "test_helper"

# Phones are stored in E.164, the join key for SMS and inbound matching, so a
# lookup is an exact, indexed match on either number.
class PhoneE164Test < ActiveSupport::TestCase
  test "user phone and mobile are stored in E.164 however they were typed" do
    user = users(:jx)
    user.update!(phone_number: "07700 900123", mobile_number: "(07700) 900.124")
    assert_equal [ "+447700900123", "+447700900124" ], [ user.reload.phone_number, user.mobile_number ]
    user.update!(phone_number: "", mobile_number: "0044 7700 900125")
    assert_equal [ nil, "+447700900125" ], [ user.reload.phone_number, user.mobile_number ]
  end

  test "a waiting list signup's phone is stored in E.164" do
    entry = WaitlistEntry.create!(service: services(:haircut), name: "Wait", email: "w@example.org", phone: "07700 900126")
    assert_equal "+447700900126", entry.reload.phone
  end

  test "the phone lookup matches either number exactly, using the indexes" do
    users(:jx).update!(phone_number: "07700 900123")
    partner = User.create!(name: "Partner", mobile_number: "07700900123", role: roles(:customer))
    assert_equal [ users(:jx), partner ].sort_by(&:id), User.customers_by_phone("+44 7700 900123").sort_by(&:id)
    assert_empty User.customers_by_phone("+447700900999")

    sql = nil
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql] if payload[:sql].include?("phone_number")
    end
    User.customers_by_phone("+447700900123")
    ActiveSupport::Notifications.unsubscribe(subscriber)
    plan = User.connection.select_rows("EXPLAIN QUERY PLAN #{sql}")
    detail = plan.map(&:last).join(" | ")
    assert_match(/index_users_on_phone_number/, detail)
    assert_match(/index_users_on_mobile_number/, detail)
  end
end
