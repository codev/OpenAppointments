require "test_helper"
require "webmock/minitest"

# Stripe Checkout: register holds the slot and sends the customer to Stripe, the
# return page verifies the session with Stripe and announces the booking once
# paid, an abandoned or expired payment releases the slot.
class PaymentsCheckoutTest < ActionDispatch::IntegrationTest
  DATE = "2026-07-20".freeze # Monday, see availability engine tests
  SESSIONS = "https://api.stripe.com/v1/checkout/sessions".freeze

  setup do
    @state = { service_id: services(:haircut).id, provider_id: users(:zane).id, date: DATE, time: "11:00" }
    @customer = { name: "Card Payer", email: "card@example.org" }
    Setting.set("payments_enabled", "1")
    Setting.set("payments_stripe_enabled", "1")
    Setting.set("payments_stripe_secret_key", "sk_test_123")
    Setting.set("payments_stripe_currency", "GBP")
    services(:haircut).update!(price: 25.50, payment_method_keys: %w[stripe])
    Notification.create!(title: "Booked", event: "created", audiences: %w[customer], channels: %w[email],
                         short_text: "Booked {{Service}}")
    Webhook.create!(name: "Hook", url: "https://hooks.example.org/ea", actions: "appointment_save")
  end

  def register(extra = {})
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/booking/register", params: {
        form: "1", **@state,
        appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id, start_datetime: "#{DATE} 11:00:00" },
        customer: @customer
      }.deep_merge(extra)
    end
  end

  def stub_create(status: 200, body: { id: "cs_test_1", url: "https://checkout.stripe.com/c/pay/cs_test_1", status: "open", payment_status: "unpaid" })
    stub_request(:post, SESSIONS).to_return(status: status, body: body.to_json)
  end

  def stub_retrieve(id, status:, payment_status:, url: nil)
    stub_request(:get, "#{SESSIONS}/#{id}")
      .to_return(status: 200, body: { id: id, status: status, payment_status: payment_status, url: url, payment_intent: "pi_1" }.to_json)
  end

  def held_booking
    Appointment.create!(start_datetime: "#{DATE} 14:00:00", end_datetime: "#{DATE} 14:30:00",
                        provider: users(:zane), customer: users(:jx), service: services(:haircut), status: "Booked",
                        payment_method: "stripe", payment_reference: "cs_test_9")
  end

  test "register holds the slot, starts a Checkout session and sends the customer to Stripe without announcing" do
    create = stub_create
    assert_no_enqueued_jobs only: [ MessageDeliveryJob, WebhookDeliveryJob ] do
      register
    end
    appointment = Appointment.order(:id).last
    assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_1"
    assert_equal "stripe", appointment.payment_method
    assert_equal "cs_test_1", appointment.payment_reference
    assert_nil appointment.paid_at
    assert_equal "Booked", appointment.status

    return_url = "http://www.example.com/booking_payment/of/#{appointment.booking_hash}"
    assert_requested(create.with { |request|
      form = Rack::Utils.parse_nested_query(request.body)
      assert_equal "Bearer sk_test_123", request.headers["Authorization"]
      assert_equal "payment", form["mode"]
      assert_equal [ "card" ], form["payment_method_types"]
      assert_equal "gbp", form.dig("line_items", "0", "price_data", "currency")
      assert_equal "2550", form.dig("line_items", "0", "price_data", "unit_amount")
      assert_equal "Trim Cut", form.dig("line_items", "0", "price_data", "product_data", "name")
      assert_equal "1", form.dig("line_items", "0", "quantity")
      assert_equal "card@example.org", form["customer_email"]
      assert_equal appointment.booking_hash, form["client_reference_id"]
      assert_equal appointment.id.to_s, form.dig("metadata", "appointment_id")
      assert_equal return_url, form["success_url"]
      assert_equal return_url, form["cancel_url"]
      assert_equal Time.new(2026, 7, 10, 12, 31, 0).to_i.to_s, form["expires_at"]
      true
    })
  end

  test "register shows a top level redirect page when the booking page is embedded" do
    Setting.set("allow_iframe_embedding", "1")
    stub_create
    register
    assert_response :success
    assert_select "a#continue-to-payment[href='https://checkout.stripe.com/c/pay/cs_test_1'][target=_top]", text: "Continue to payment"
    assert_select "script", text: /window\.top\.location\.replace\("https:\/\/checkout\.stripe\.com\/c\/pay\/cs_test_1"\)/
  end

  test "a failed session start removes the booking and shows the form again" do
    stub_create(status: 401, body: { error: { message: "Invalid API Key provided" } })
    assert_no_difference "Appointment.count" do
      register
    end
    assert_response :success
    assert_select "#form-message", text: I18n.t("ea.payments_checkout_failed")
  end

  test "the return page marks a paid session, announces the booking and continues to the confirmation" do
    appointment = held_booking
    stub_retrieve("cs_test_9", status: "complete", payment_status: "paid")
    assert_enqueued_jobs 1, only: MessageDeliveryJob do
      assert_enqueued_jobs 1, only: WebhookDeliveryJob do
        get "/booking_payment/of/#{appointment.booking_hash}"
      end
    end
    assert_redirected_to "/booking_confirmation/of/#{appointment.booking_hash}"
    appointment.reload
    assert appointment.paid_at
    assert_equal "pi_1", appointment.payment_reference
    assert_equal "paid", appointment.payment_status

    # Already paid: nothing is asked of Stripe and nothing goes out again.
    assert_no_enqueued_jobs only: MessageDeliveryJob do
      get "/booking_payment/of/#{appointment.booking_hash}"
    end
    assert_redirected_to "/booking_confirmation/of/#{appointment.booking_hash}"
    assert_requested :get, "#{SESSIONS}/cs_test_9", times: 1
  end

  test "the return page offers to try again or cancel while the session is open" do
    appointment = held_booking
    stub_retrieve("cs_test_9", status: "open", payment_status: "unpaid", url: "https://checkout.stripe.com/c/pay/cs_test_9")
    get "/booking_payment/of/#{appointment.booking_hash}"
    assert_response :success
    assert_select "h3", text: "Payment not completed"
    assert_select "a#try-again[href='https://checkout.stripe.com/c/pay/cs_test_9']", text: "Try again"
    assert_select "form[action='/booking_payment/abandon/#{appointment.booking_hash}'] button", text: "Cancel booking"
    assert_equal "Booked", appointment.reload.status
    assert_nil appointment.paid_at
  end

  test "an expired session releases the slot" do
    appointment = held_booking
    stub_retrieve("cs_test_9", status: "expired", payment_status: "unpaid")
    assert_no_enqueued_jobs only: [ MessageDeliveryJob, WebhookDeliveryJob ] do
      get "/booking_payment/of/#{appointment.booking_hash}"
    end
    assert_response :success
    assert_select "h3", text: "Payment time ran out"
    assert_select "a#book-again[href='/']", text: "Book again"
    assert_equal "Cancelled", appointment.reload.status

    get "/booking_payment/of/#{appointment.booking_hash}"
    assert_select "h3", text: "Payment time ran out"
    assert_requested :get, "#{SESSIONS}/cs_test_9", times: 1
  end

  test "cancel booking releases the slot and expires the session" do
    appointment = held_booking
    expire = stub_request(:post, "#{SESSIONS}/cs_test_9/expire").to_return(status: 200, body: { id: "cs_test_9", status: "expired" }.to_json)
    post "/booking_payment/abandon/#{appointment.booking_hash}"
    assert_response :success
    assert_select "h3", text: "Appointment Cancelled"
    assert_select "p", text: I18n.t("ea.payments_abandoned_text")
    assert_select "a#book-again[href='/']"
    assert_equal "Cancelled", appointment.reload.status
    assert_requested expire

    appointment.update!(appointment_status: AppointmentStatus.of("booked"), paid_at: Time.current)
    post "/booking_payment/abandon/#{appointment.booking_hash}"
    assert_redirected_to "/booking_confirmation/of/#{appointment.booking_hash}"
    assert_equal "Booked", appointment.reload.status, "a paid booking is not cancelled from here"
  end

  test "an unknown hash goes home and a booking without a checkout payment goes to its confirmation" do
    get "/booking_payment/of/nope"
    assert_redirected_to "/"
    post "/booking_payment/abandon/nope"
    assert_redirected_to "/"

    appointment = appointments(:upcoming)
    get "/booking_payment/of/#{appointment.booking_hash}"
    assert_redirected_to "/booking_confirmation/of/#{appointment.booking_hash}"
  end

  test "a booking without a checkout method is announced straight away" do
    services(:haircut).update!(payment_method_keys: %w[in_person])
    assert_enqueued_jobs 1, only: MessageDeliveryJob do
      register
    end
    assert_redirected_to "/booking_confirmation/of/#{Appointment.order(:id).last.booking_hash}"
  end
end
