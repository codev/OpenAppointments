require "net/http"

# Stripe Checkout (https://dashboard.stripe.com/). The customer is sent to a
# hosted payment page after confirming the booking. REST calls use the secret
# key as a bearer token with form-encoded bodies.
module Payments
  module Stripe
    module_function

    API_BASE = "https://api.stripe.com/v1".freeze
    # Charged in whole units; every other currency in hundredths.
    ZERO_DECIMAL_CURRENCIES = %w[bif clp djf gnf jpy kmf krw mga pyg rwf ugx vnd vuv xaf xof xpf].freeze

    def key = "stripe"

    def label = "Stripe"

    def checkout? = true

    def tracks_payment? = true

    def enabled?(config = Payments.config)
      config["payments_stripe_enabled"] == "1" && secret_key(config).present?
    end

    def secret_key(config = Payments.config) = config["payments_stripe_secret_key"]

    def webhook_secret(config = Payments.config) = config["payments_stripe_webhook_secret"]

    def currency(config = Payments.config) = config["payments_stripe_currency"].to_s.downcase

    def instructions(_config = Payments.config) = I18n.t("ea.payments_stripe_instructions")

    # [ok, error]: the balance resource answers 200 to a valid secret key.
    def check_credentials(config = Payments.config)
      request!(:get, "/balance", config: config)
      [ true, nil ]
    rescue StandardError => e
      [ false, e.message ]
    end

    # Starts a hosted payment for the appointment: the session row, with "id"
    # and the "url" to send the customer to. Cards only, so the payment is
    # confirmed by the time the customer is sent back.
    def create_checkout_session(appointment, success_url:, cancel_url:, expires_at:, config: Payments.config)
      service = appointment.service
      params = {
        "mode" => "payment",
        "payment_method_types[]" => "card",
        "line_items[0][quantity]" => 1,
        "line_items[0][price_data][currency]" => currency(config),
        "line_items[0][price_data][unit_amount]" => minor_units(service.price, currency(config)),
        "line_items[0][price_data][product_data][name]" => service.name,
        "line_items[0][price_data][product_data][description]" =>
          "#{appointment.provider.name}, #{appointment.start_datetime.strftime('%Y-%m-%d %H:%M')}",
        "client_reference_id" => appointment.booking_hash,
        "metadata[appointment_id]" => appointment.id,
        "success_url" => success_url,
        "cancel_url" => cancel_url,
        "expires_at" => expires_at.to_i
      }
      params["customer_email"] = appointment.customer.email if appointment.customer.email.present?
      request!(:post, "/checkout/sessions", params, config: config)
    end

    # Where a started payment stands: {state: :paid | :open | :expired, url:,
    # payment_id:}; url is the payment page while the session is open and
    # payment_id the charge to find in the Stripe dashboard.
    def checkout_state(reference, config: Payments.config)
      session = request!(:get, "/checkout/sessions/#{reference}", config: config)
      state = :expired
      state = :open if session["status"] == "open"
      state = :paid if session["payment_status"] == "paid"
      { state: state, url: session["url"], payment_id: session["payment_intent"] }
    end

    # Stripe-Signature is "t=<unix time>,v1=<hmac>", with a v1 per active
    # signing secret; the hmac is SHA256 over "<t>.<payload>". Without a
    # secret configured there is nothing to check against.
    def webhook_signature_valid?(payload, header, config: Payments.config, now: Time.now, tolerance: 5.minutes)
      secret = webhook_secret(config)
      return true if secret.blank?

      pairs = header.to_s.split(",").map { |pair| pair.strip.split("=", 2) }
      timestamp = pairs.find { |key, _| key == "t" }&.last.to_i
      return false if (now.to_i - timestamp).abs > tolerance

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
      pairs.any? { |key, value| key == "v1" && ActiveSupport::SecurityUtils.secure_compare(expected, value.to_s) }
    end

    def expire_checkout_session(reference, config: Payments.config)
      request!(:post, "/checkout/sessions/#{reference}/expire", config: config)
    end

    def minor_units(price, currency)
      amount = BigDecimal(price.to_s)
      amount *= 100 unless ZERO_DECIMAL_CURRENCIES.include?(currency.to_s.downcase)
      amount.round.to_i
    end

    # One API call; the parsed JSON on success, an error naming Stripe's
    # message otherwise. params are form-encoded (Stripe's bracket style).
    def request!(method, path, params = {}, config: Payments.config)
      uri = URI("#{API_BASE}#{path}")
      request = method == :get ? Net::HTTP::Get.new(uri.request_uri) : Net::HTTP::Post.new(uri.request_uri)
      request["Authorization"] = "Bearer #{secret_key(config)}"
      request.set_form_data(params) if method == :post && params.any?
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15
      response = http.request(request)
      body = response.body.to_s
      return JSON.parse(body) if response.is_a?(Net::HTTPSuccess)

      detail = JSON.parse(body).dig("error", "message") rescue body.truncate(200)
      raise "Stripe #{response.code}: #{detail}"
    end
  end
end
