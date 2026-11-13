require "test_helper"

# Once an appointment has happened, the customer's unread messages are marked
# read: the stylist has seen them in person. The Inbox is untouched (done_at
# stays nil), so the message still waits there for an admin.
class MessageReadsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @customer = users(:jx)
    @zane = users(:zane) # Europe/London
    @start = Time.new(2026, 7, 21, 10, 0, 0) # stylist wall clock, 09:00 UTC in July
  end

  def incoming(at, customer: @customer)
    travel_to(at) do
      Message.create!(direction: "incoming", channel: "email", status: "received",
                      from_address: customer.email, customer_id: customer.id, body: "On my way")
    end
  end

  def book(status: "Booked", start: @start, customer: @customer)
    Appointment.create!(start_datetime: start, end_datetime: start + 30.minutes, provider: @zane,
                        customer: customer, service: services(:haircut), status: status)
  end

  def london(hour, minute) = Time.find_zone!("Europe/London").local(2026, 7, 21, hour, minute)

  test "messages received before the appointment are read once it has ended" do
    book
    message = incoming(london(8, 0))

    MessageReads.after_appointments(london(10, 29))
    assert_nil message.reload.read_at

    MessageReads.after_appointments(london(10, 31))
    assert message.reload.read?
    assert_nil message.done_at
  end

  test "a message arriving after the appointment ended stays unread" do
    book
    later = incoming(london(11, 0))
    MessageReads.after_appointments(london(12, 0))
    assert_nil later.reload.read_at
  end

  test "cancelled and no-show appointments do not mark anything read" do
    [ "Cancelled", "No Show" ].each { |status| book(status: status) }
    message = incoming(london(8, 0))
    MessageReads.after_appointments(london(12, 0))
    assert_nil message.reload.read_at
  end

  test "other customers' messages are untouched" do
    book
    other = User.create!(name: "Other Person", email: "other@example.org", role: roles(:customer))
    message = incoming(london(8, 0), customer: other)
    MessageReads.after_appointments(london(12, 0))
    assert_nil message.reload.read_at
  end

  test "the job runs the scan on the recurring schedule" do
    book
    message = incoming(london(8, 0))
    travel_to(london(12, 0)) { MessageReadScanJob.perform_now }
    assert message.reload.read?
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"))["production"]["message_read_scan"]
    assert_equal "MessageReadScanJob", schedule["class"]
    assert_equal "every 5 minutes", schedule["schedule"]
  end
end
