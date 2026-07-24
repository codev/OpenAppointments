# Public webhook endpoints for incoming SMS. The URL carries the secret inbound
# token; Twilio requests are additionally signature-checked. Senders are matched
# to customers by E.164 phone; unmatched messages land in the Unknown Inbox.
class InboundMessagesController < ActionController::Base
  skip_forgery_protection

  CHANNELS = %w[twilio plivo textanywhere].freeze

  def receive
    channel = params[:channel].to_s
    return head :not_found unless CHANNELS.include?(channel) && token_valid?

    adapter = Messaging.channel(channel)
    return head :not_found unless adapter.enabled? && adapter.incoming?
    return head :forbidden if channel == "twilio" && !twilio_signature_valid?

    from, to, body = extract(channel)
    return head :unprocessable_entity if from.blank?

    Message.create!(
      direction: "incoming", channel: channel, status: "received",
      from_address: from, to_address: to, customer_id: match_customer(from)&.id, body: body
    )
    channel == "twilio" ? render(xml: "<Response></Response>") : head(:ok)
  end

  private

  def token_valid?
    token = Setting.get("messages_inbound_token").to_s
    token.present? && ActiveSupport::SecurityUtils.secure_compare(params[:token].to_s, token)
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
    else
      [ (params[:from].presence || params[:originator]).to_s,
        (params[:to].presence || params[:destination]).to_s,
        (params[:message].presence || params[:body]).to_s ]
    end
  end

  def match_customer(from)
    User.customers.where(phone_number: from).or(User.customers.where(mobile_number: from)).first
  end
end
