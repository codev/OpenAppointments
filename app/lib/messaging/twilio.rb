# Twilio SMS (https://www.twilio.com/console). Messages API with account SID +
# auth token basic auth.
module Messaging
  module Twilio
    module_function

    def key = "twilio"

    def label = "Twilio"

    def supports_long_text? = false

    def enabled?
      Setting.get("messages_twilio_enabled") == "1" &&
        account_sid.present? && auth_token.present? && from_number.present?
    end

    def incoming?
      Setting.get("messages_twilio_incoming") == "1"
    end

    def account_sid = Setting.get("messages_twilio_account_sid").to_s

    def auth_token = Setting.get("messages_twilio_auth_token").to_s

    def from_number = Setting.get("messages_twilio_from").to_s

    def address_for(user)
      Messaging::Template.sms_address(user)
    end

    def deliver(message)
      uri = URI("https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json")
      request = Net::HTTP::Post.new(uri.request_uri)
      request.basic_auth(account_sid, auth_token)
      request.set_form_data("From" => from_number, "To" => message.to_address, "Body" => message.body)
      post!(uri, request)
    end

    # Twilio request validation: HMAC-SHA1 over URL + sorted POST params.
    def valid_signature?(signature, url, post_params)
      data = url + post_params.sort.map { |key, value| "#{key}#{value}" }.join
      digest = OpenSSL::HMAC.digest("sha1", auth_token, data)
      ActiveSupport::SecurityUtils.secure_compare(Base64.strict_encode64(digest), signature.to_s)
    end

    def post!(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15
      response = http.request(request)
      return if response.is_a?(Net::HTTPSuccess)

      raise "Twilio #{response.code}: #{response.body.to_s.truncate(200)}"
    end
  end
end
