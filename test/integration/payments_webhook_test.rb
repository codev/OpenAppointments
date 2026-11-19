require "test_helper"
require "webmock/minitest"

# Stripe's webhook events: the event only names the booking, the payment is
# confirmed with Stripe directly. The signature is checked when a signing
# secret is configured.
class PaymentsWebhookTest < ActionDispatch::IntegrationTest
  SESSIONS = "https://api.stripe.com/v1/checkout/sessions".freeze
  SECRET = "whsec_test_secret".freeze

  setup do
    Setting.set("payments_enabled", "1")
    Setting.set("payments_stripe_enabled", "1")
    Setting.set("payments_stripe_secret_key", "sk_test_123")
    Setting.set("payments_stripe_webhook_secret", SECRET)
    @appointment = Appointment.create!(start_datetime: "2026-07-20 14:00:00", end_datetime: "2026-07-20 14:30:00",
                                       provider: users(:zane), customer: users(:jx), service: services(:haircut), status: "Booked",
                                       payment_method: "stripe", payment_reference: "cs_test_9")
    Notification.create!(title: "Booked", event: "created", audiences: %w[customer], channels: %w[email], short_text: "Booked")
  end

  def event(type, session_id: "cs_test_9", reference: @appointment.booking_hash)
    { id: "evt_1", type: type, data: { object: { id: session_id, object: "checkout.session", client_reference_id: reference } } }.to_json
  end

  def signature(body, secret: SECRET, at: Time.now)
    "t=#{at.to_i},v1=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{at.to_i}.#{body}")}"
  end

  def post_event(body, headers = { "Stripe-Signature" => signature(body) })
    post "/payments/stripe/webhook", params: body, headers: headers.merge("CONTENT_TYPE" => "application/json")
  end

  def stub_retrieve(status:, payment_status:)
    stub_request(:get, "#{SESSIONS}/cs_test_9")
      .to_return(status: 200, body: { id: "cs_test_9", status: status, payment_status: payment_status, payment_intent: "pi_1" }.to_json)
  end

  test "a completed session is confirmed with Stripe, marked paid and announced" do
    stub_retrieve(status: "complete", payment_status: "paid")
    assert_enqueued_jobs 1, only: MessageDeliveryJob do
      post_event(event("checkout.session.completed"))
    end
    assert_response :success
    @appointment.reload
    assert @appointment.paid_at
    assert_equal "pi_1", @appointment.payment_reference
  end

  test "an expired session releases the booking" do
    stub_retrieve(status: "expired", payment_status: "unpaid")
    assert_no_enqueued_jobs only: MessageDeliveryJob do
      post_event(event("checkout.session.expired"))
    end
    assert_response :success
    assert_equal "Cancelled", @appointment.reload.status
  end

  test "a bad, stale or missing signature is refused and Stripe is not asked" do
    body = event("checkout.session.completed")
    post_event(body, { "Stripe-Signature" => signature(body, secret: "whsec_other") })
    assert_response :bad_request
    post_event(body, { "Stripe-Signature" => signature(body, at: 10.minutes.ago) })
    assert_response :bad_request
    post_event(body, {})
    assert_response :bad_request
    assert_not_requested :get, "#{SESSIONS}/cs_test_9"
    assert_equal "Booked", @appointment.reload.status
  end

  test "without a signing secret the event is taken as it is, since the payment is confirmed with Stripe anyway" do
    Setting.set("payments_stripe_webhook_secret", "")
    stub_retrieve(status: "complete", payment_status: "paid")
    post_event(event("checkout.session.completed"), {})
    assert_response :success
    assert @appointment.reload.paid_at
  end

  test "events for other types, unknown bookings, other sessions or settled bookings are acknowledged and ignored" do
    post_event(event("payment_intent.succeeded"))
    assert_response :success
    post_event(event("checkout.session.completed", reference: "nope"))
    assert_response :success
    post_event(event("checkout.session.completed", session_id: "cs_other"))
    assert_response :success
    @appointment.update!(paid_at: Time.current)
    post_event(event("checkout.session.completed"))
    assert_response :success
    assert_not_requested :get, "#{SESSIONS}/cs_test_9"

    post_event("not json", { "Stripe-Signature" => signature("not json") })
    assert_response :bad_request
  end

  test "a Stripe error answers 500 so Stripe retries" do
    stub_request(:get, "#{SESSIONS}/cs_test_9").to_return(status: 500, body: "boom")
    assert_raises(RuntimeError) { post_event(event("checkout.session.completed")) }
    assert_equal "Booked", @appointment.reload.status
  end

  test "the Stripe settings page shows the webhook URL" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/payments_stripe_settings"
    assert_select "input#stripe-webhook-url[readonly][value='http://www.example.com/payments/stripe/webhook']"
    assert_select "#payments-stripe-settings", text: /checkout\.session\.completed/
  end
end
