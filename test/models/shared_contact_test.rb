require "test_helper"

# Partners and family may share an email or phone. A message from a shared
# contact goes to the customer with the next upcoming appointment, else the
# latest past one, else the most recently updated customer.
class SharedContactTest < ActiveSupport::TestCase
  setup do
    @alex = User.create!(name: "Alex Shared", email: "Home@Example.org", phone_number: "07700 900555", role: roles(:customer))
    @blake = User.create!(name: "Blake Shared", email: "home@example.org", mobile_number: "+447700900555", role: roles(:customer))
  end

  def book(customer, start, status: "Booked")
    Appointment.create!(start_datetime: start, end_datetime: start + 30.minutes, provider: users(:zane),
                        customer: customer, service: services(:haircut), status: status)
  end

  test "every customer using the email or phone is a candidate, once each" do
    assert_equal [ @alex, @blake ].sort_by(&:id), User.customers_by_contact(email: "HOME@example.org").sort_by(&:id)
    assert_equal [ @alex, @blake ].sort_by(&:id), User.customers_by_contact(phone: "+447700900555").sort_by(&:id)
    assert_equal [ @alex, @blake ].sort_by(&:id),
                 User.customers_by_contact(email: "home@example.org", phone: "+447700900555").sort_by(&:id)
    assert_equal [], User.customers_by_contact(email: "nobody@example.org")
  end

  test "the next upcoming appointment decides" do
    book(@alex, 5.days.from_now)
    book(@blake, 2.days.from_now)
    book(@alex, 1.day.ago)
    assert_equal @blake, User.likely_sender([ @alex, @blake ])
  end

  test "with nothing upcoming the latest past appointment decides, ignoring cancelled ones" do
    book(@alex, 10.days.ago)
    book(@blake, 20.days.ago)
    book(@blake, 2.days.from_now, status: "Cancelled")
    assert_equal @alex, User.likely_sender([ @alex, @blake ])
  end

  test "with no appointments the most recently updated customer is chosen" do
    @alex.touch
    assert_equal @alex, User.likely_sender([ @blake, @alex ])
    assert_nil User.likely_sender([])
  end
end
