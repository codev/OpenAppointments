require "test_helper"

class CleanupTest < ActiveSupport::TestCase
  setup { Setting.set("data_retention_days", "365") }

  def make_customer(created_at:)
    User.create!(name: "Old Customer", email: "old#{created_at.to_i}@example.org",
                 role: Role.find_by(slug: "customer"), created_at: created_at)
  end

  test "disabled when retention is zero" do
    Setting.set("data_retention_days", "0")
    make_customer(created_at: 5.years.ago)
    assert_no_difference "User.customers.count" do
      result = Cleanup.run
      assert_equal false, result[:enabled]
    end
  end

  test "deletes a stale customer with no recent appointment" do
    stale = make_customer(created_at: 2.years.ago)
    assert_difference "User.customers.count", -1 do
      result = Cleanup.run
      assert_equal 1, result[:deleted]
    end
    assert_nil User.find_by(id: stale.id)
  end

  test "keeps a stale customer who has a recent appointment" do
    stale = make_customer(created_at: 2.years.ago)
    Appointment.create!(provider: users(:zane), customer: stale, service: services(:haircut),
                        start_datetime: 1.day.from_now.strftime("%Y-%m-%d %H:%M:%S"),
                        end_datetime: (1.day.from_now + 30.minutes).strftime("%Y-%m-%d %H:%M:%S"))
    assert_no_difference "User.customers.count" do
      Cleanup.run
    end
  end

  test "keeps a recently created customer" do
    make_customer(created_at: 1.day.ago)
    assert_no_difference "User.customers.count" do
      Cleanup.run
    end
  end

  test "deleting cascades the customer's appointments" do
    stale = make_customer(created_at: 2.years.ago)
    Appointment.create!(provider: users(:zane), customer: stale, service: services(:haircut),
                        start_datetime: "2020-01-01 09:00:00", end_datetime: "2020-01-01 09:30:00")
    assert_difference "Appointment.count", -1 do
      Cleanup.run
    end
  end
end
