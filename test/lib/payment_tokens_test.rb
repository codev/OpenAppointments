require "test_helper"

# {{Payment Method}}, {{Payment Status}} and {{Payment Instructions}} let a
# template tell the customer how to pay and the stylist whether they have.
class PaymentTokensTest < ActiveSupport::TestCase
  setup do
    @appointment = appointments(:upcoming)
    Setting.set("payments_bank_transfer_instructions", "Sort code 12-34-56\nAccount 12345678")
  end

  def render(text)
    context = Messaging::Template.appointment_context(appointment: @appointment, service: services(:haircut),
                                                      provider: users(:zane), customer: users(:jx))
    Messaging::Template.render(text, context)
  end

  test "the tokens are listed" do
    assert_includes Messaging::Template::TOKENS, "Payment Method"
    assert_includes Messaging::Template::TOKENS, "Payment Status"
    assert_includes Messaging::Template::TOKENS, "Payment Instructions"
  end

  test "a booking without a payment method renders them empty" do
    assert_equal "Pay: //", render("Pay: {{Payment Method}}/{{Payment Status}}/{{Payment Instructions}}")
  end

  test "an unpaid bank transfer carries the method, Unpaid and the instructions" do
    @appointment.update!(payment_method: "bank_transfer")
    assert_equal "Bank transfer, Unpaid\nSort code 12-34-56\nAccount 12345678",
                 render("{{Payment Method}}, {{Payment Status}}\n{{Payment Instructions}}")
  end

  test "a paid Stripe booking reads Paid" do
    @appointment.update!(payment_method: "stripe", paid_at: Time.current)
    assert_equal "Stripe: Paid", render("{{Payment Method}}: {{Payment Status}}")
  end
end
