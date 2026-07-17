# Delivers one webhook call (EA Webhooks_client::call). Body shape {action:, payload:}
# with the optional secret header. EA swallows errors; here transient failures retry
# with backoff and are discarded after the attempts run out.
class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(webhook_id, action, payload)
    webhook = Webhook.find_by(id: webhook_id)
    return unless webhook

    uri = URI.parse(webhook.url)
    return unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.verify_mode = webhook.is_ssl_verified ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
    if webhook.secret_header.present? && webhook.secret_token.present?
      request[webhook.secret_header] = webhook.secret_token
    end
    request.body = { action: action, payload: payload }.to_json

    response = http.request(request)
    Rails.logger.info("Webhook #{webhook.id} (#{action}) responded #{response.code}")
  end
end
