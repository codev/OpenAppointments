# Stripe's webhook events for Checkout Sessions. An event only says which
# booking to look at: the payment itself is confirmed with Stripe, so a forged
# event can do no more than prompt a check. The signature is verified when a
# signing secret is configured.
class PaymentsStripeWebhookController < ActionController::Base
  skip_forgery_protection

  EVENTS = %w[checkout.session.completed checkout.session.expired].freeze

  # POST /payments/stripe/webhook
  def receive
    payload = request.raw_post
    return head :bad_request unless Payments::Stripe.webhook_signature_valid?(payload, request.headers["Stripe-Signature"])

    event = JSON.parse(payload)
    settle(event.dig("data", "object") || {}) if EVENTS.include?(event["type"])
    render json: { received: true }
  rescue JSON::ParserError
    head :bad_request
  end

  private

  # The session names its booking; only a booking still waiting on that
  # session is looked at. A provider error answers 500 so Stripe retries.
  def settle(session)
    appointment = Appointment.find_by(booking_hash: session["client_reference_id"].to_s)
    return unless appointment && appointment.payment_reference == session["id"]
    return unless BookingPayment.checkout?(appointment) && !appointment.frees_slot?

    BookingPayment.settle(appointment)
  end
end
