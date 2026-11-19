require "test_helper"
require "webmock/minitest"

# The sweep for checkout bookings nobody returned from: each one past its hold
# is settled with the provider, so a missed webhook still marks a paid booking
# and an expired session still releases the slot.
class BookingPaymentTest < ActiveSupport::TestCase
  SESSIONS = "https://api.stripe.com/v1/checkout/sessions".freeze

  setup do
    Setting.set("payments_stripe_enabled", "1")
    Setting.set("payments_stripe_secret_key", "sk_test_123")
    @now = Time.new(2026, 7, 10, 12, 0, 0)
  end

  def held(reference, booked_at:, method: "stripe", start: "2026-07-20 14:00:00")
    Appointment.create!(start_datetime: start, end_datetime: Time.parse(start) + 30.minutes, book_datetime: booked_at,
                        provider: users(:zane), customer: users(:jx), service: services(:haircut), status: "Booked",
                        payment_method: method, payment_reference: reference)
  end

  def stub_retrieve(id, status:, payment_status:)
    stub_request(:get, "#{SESSIONS}/#{id}")
      .to_return(status: 200, body: { id: id, status: status, payment_status: payment_status, payment_intent: "pi_#{id}" }.to_json)
  end

  test "the sweep settles held bookings past their hold and leaves fresh ones alone" do
    expired = held("cs_old", booked_at: @now - 40.minutes)
    paid = held("cs_paid", booked_at: @now - 40.minutes, start: "2026-07-20 15:00:00")
    fresh = held("cs_new", booked_at: @now - 10.minutes, start: "2026-07-20 16:00:00")
    bank = held(nil, booked_at: @now - 40.minutes, method: "bank_transfer", start: "2026-07-20 17:00:00")
    stub_retrieve("cs_old", status: "expired", payment_status: "unpaid")
    stub_retrieve("cs_paid", status: "complete", payment_status: "paid")

    assert_equal 2, BookingPayment.sweep(@now)

    assert_equal "Cancelled", expired.reload.status
    assert paid.reload.paid_at
    assert_equal "pi_cs_paid", paid.payment_reference
    assert_equal "Booked", fresh.reload.status
    assert_nil fresh.paid_at
    assert_equal "Booked", bank.reload.status
    assert_not_requested :get, "#{SESSIONS}/cs_new"
  end

  test "the sweep looks no further back than a day, so old rows are not retried forever" do
    stale = held("pi_refunded", booked_at: @now - 2.days)
    assert_equal 0, BookingPayment.sweep(@now)
    assert_equal "Booked", stale.reload.status
    assert_not_requested :get, "#{SESSIONS}/pi_refunded"
  end

  test "a payment is confirmed and announced once however many reports arrive" do
    appointment = held("cs_twice", booked_at: @now)
    Notification.create!(title: "Booked", event: "created", audiences: %w[customer], channels: %w[email], short_text: "Booked")
    stale_copy = Appointment.find(appointment.id)
    assert_difference "Message.count", 1 do
      BookingPayment.confirm_paid(appointment, "pi_1")
      BookingPayment.confirm_paid(stale_copy, "pi_1")
    end
    assert_equal "pi_1", appointment.reload.payment_reference
  end

  test "a provider error on one booking does not stop the sweep" do
    broken = held("cs_broken", booked_at: @now - 40.minutes)
    expired = held("cs_old", booked_at: @now - 40.minutes, start: "2026-07-20 15:00:00")
    stub_request(:get, "#{SESSIONS}/cs_broken").to_return(status: 500, body: "boom")
    stub_retrieve("cs_old", status: "expired", payment_status: "unpaid")

    assert_equal 1, BookingPayment.sweep(@now)
    assert_equal "Booked", broken.reload.status
    assert_equal "Cancelled", expired.reload.status
  end

  test "the sweep job runs the sweep" do
    held("cs_old", booked_at: 40.minutes.ago)
    stub_retrieve("cs_old", status: "expired", payment_status: "unpaid")
    PaymentSweepJob.perform_now
    assert_equal "Cancelled", Appointment.find_by(payment_reference: "cs_old").status
  end
end
