require "test_helper"

# Payment state on appointments and the accepted methods on services.
class PaymentFieldsTest < ActiveSupport::TestCase
  test "an appointment without a payment method has no payment status" do
    assert_equal "none", appointments(:upcoming).payment_status
  end

  test "an appointment with a method is unpaid until paid_at is set" do
    appointment = appointments(:upcoming)
    appointment.payment_method = "stripe"
    assert_equal "unpaid", appointment.payment_status
    assert appointment.unpaid?

    appointment.paid_at = Time.current
    assert_equal "paid", appointment.payment_status
    assert_not appointment.unpaid?
  end

  test "mark_paid! stamps the time and keeps the reference" do
    appointment = appointments(:upcoming)
    appointment.update!(payment_method: "stripe", payment_reference: "cs_test_1")
    travel_to Time.new(2026, 7, 1, 12, 0, 0) do
      appointment.mark_paid!
    end
    appointment.reload
    assert_equal Time.new(2026, 7, 1, 12, 0, 0), appointment.paid_at
    assert_equal "cs_test_1", appointment.payment_reference
    assert_equal "paid", appointment.payment_status
    assert_not appointment.mark_paid!(reference: "pi_late"), "a second claim is refused"
    assert_equal "cs_test_1", appointment.reload.payment_reference
  end

  test "a service stores its accepted payment methods as a key list" do
    service = services(:haircut)
    assert_equal [], service.payment_method_keys

    service.payment_method_keys = [ "stripe", "", "bank_transfer", "stripe" ]
    service.save!
    assert_equal "stripe,bank_transfer", service.reload.payment_methods
    assert_equal %w[stripe bank_transfer], service.payment_method_keys
  end
end
