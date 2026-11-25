# Public webhook endpoints for incoming SMS and, from the SMS Gateway phone,
# delivery and failure reports on texts we sent. The URL carries the secret
# inbound token; Twilio, SMS Gateway and QuickSMS requests are additionally
# signature-checked. Senders are matched
# to customers by E.164 phone (User.likely_sender when several share it);
# unmatched messages sit in the Inbox as unknown senders (customer nil).
# A matched message notifies the customer's stylist.
class InboundMessagesController < ActionController::Base
  skip_forgery_protection

  CHANNELS = %w[twilio plivo textanywhere smsgateway quicksms].freeze
  # The phone's report events and the status each sets on our message.
  SMS_GATEWAY_REPORTS = { "sms:sent" => "sent", "sms:delivered" => "delivered", "sms:failed" => "failed" }.freeze

  def receive
    channel = params[:channel].to_s
    return head :not_found unless CHANNELS.include?(channel) && token_valid?

    adapter = Messaging.channel(channel)
    return head :not_found unless adapter.enabled?
    return head :forbidden if channel == "smsgateway" && !sms_gateway_signature_valid?
    return sms_gateway_report if channel == "smsgateway" && SMS_GATEWAY_REPORTS.key?(params[:event].to_s)
    return head :not_found unless adapter.incoming?
    return head :forbidden if channel == "twilio" && !twilio_signature_valid?
    return head :forbidden if channel == "quicksms" && !quicksms_signature_valid?

    from, to, body = extract(channel)
    return head :unprocessable_entity if from.blank?

    message = Message.create!(
      direction: "incoming", channel: channel, status: "received",
      from_address: from, to_address: to, customer_id: match_customer(from)&.id, body: body
    )
    Notifications.customer_message_received(message)
    channel == "twilio" ? render(xml: "<Response></Response>") : head(:ok)
  end

  private

  # The phone reports on a text by the id the server gave it when we sent it.
  def sms_gateway_report
    payload = params[:payload] || {}
    status = SMS_GATEWAY_REPORTS[params[:event].to_s]
    error = status == "failed" ? I18n.t("ea.messages_smsgateway_phone_failed", default: "Phone could not send it: {{reason}}")
                                     .sub("{{reason}}", payload[:reason].to_s) : nil
    Message.apply_provider_report("smsgateway", payload[:messageId].to_s, status, error: error)
    head :ok
  end

  def token_valid?
    token = Setting.get("messages_inbound_token").to_s
    token.present? && ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, token)
  end

  # HMAC over raw body + timestamp; required whenever a signing key is set.
  def sms_gateway_signature_valid?
    return true if Messaging::SmsGateway.signing_key.blank?

    Messaging::SmsGateway.valid_signature?(
      request.headers["X-Signature"], request.headers["X-Timestamp"], request.raw_post
    )
  end

  # HMAC over "timestamp.body"; required whenever a signing secret is set.
  def quicksms_signature_valid?
    return true if Messaging::Quicksms.signing_secret.blank?

    Messaging::Quicksms.valid_signature?(
      request.headers["X-QuickSMS-Signature"], request.headers["X-QuickSMS-Timestamp"], request.raw_post
    )
  end

  def twilio_signature_valid?
    Messaging::Twilio.valid_signature?(
      request.headers["X-Twilio-Signature"], request.original_url,
      request.request_parameters.to_h { |key, value| [ key.to_s, value.to_s ] }
    )
  end

  def extract(channel)
    case channel
    when "twilio" then [ params[:From].to_s, params[:To].to_s, params[:Body].to_s ]
    when "plivo" then [ params[:From].to_s, params[:To].to_s, params[:Text].to_s ]
    when "quicksms" then [ e164(params[:from]), e164(params[:to]), params[:content].to_s ]
    when "smsgateway"
      payload = params[:payload] || {}
      [ e164(payload[:sender]), e164(payload[:recipient]), payload[:message].to_s ]
    else
      [ (params[:from].presence || params[:originator]).to_s,
        (params[:to].presence || params[:destination]).to_s,
        (params[:message].presence || params[:body]).to_s ]
    end
  end

  # Device payloads may omit the plus on international numbers.
  def e164(value)
    value = value.to_s.strip
    value.match?(/\A\d{10,15}\z/) ? "+#{value}" : value
  end

  def match_customer(from)
    User.likely_sender(User.customers_by_contact(phone: from))
  end
end
