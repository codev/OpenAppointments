# Stripe Checkout (https://dashboard.stripe.com/). The customer is sent to a
# hosted payment page after confirming the booking. REST calls use the secret
# key as a bearer token with form-encoded bodies.
module Payments
  module Stripe
    module_function

    API_BASE = "https://api.stripe.com/v1".freeze

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
