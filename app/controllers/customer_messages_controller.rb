# Customer page messages section: conversation listing (marks incoming read)
# and manual sends over one or all enabled providers.
class CustomerMessagesController < ApplicationController
  include BackendPage

  before_action :require_session

  # POST /customer_messages/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :customers)

    customer_id = params.require(:customer_id).to_i
    raise ArgumentError, "Invalid customer ID provided." unless customer_id.positive?
    return head :forbidden unless customer_access?(customer_id)

    messages = Message.where(customer_id: customer_id).newest_first.limit(200).to_a
    Message.mark_read_for_customer(customer_id)
    render json: messages.map { |message| message_row(message) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /customer_messages/send
  def send_message
    raise ArgumentError, "Forbidden" if cannot?(:edit, :customers)

    customer_id = params.require(:customer_id).to_i
    return head :forbidden unless customer_access?(customer_id)

    customer = User.customers.find(customer_id)
    body = params.require(:body).to_s.strip
    raise ArgumentError, "The message text is required." if body.blank?

    channels = requested_channels(params[:channel].to_s)
    raise ArgumentError, "No enabled provider was selected." if channels.empty?

    # Spec: sign off with - {{Provider/Logged In User Name}} - {{Company Name}}
    signed_body = "#{body}\n\n- #{current_user.name} - #{Setting.get('company_name', '')}"
    subject = Messaging::Template.render(Messaging.email_subject_template,
                                         Messaging::Template.base_context)

    created = channels.filter_map do |adapter|
      address = adapter.address_for(customer)
      next if address.blank?

      message = Message.create!(
        direction: "outgoing", channel: adapter.key, audience: "customer",
        to_address: address, customer_id: customer.id, sent_by_id: current_user.id,
        subject: adapter.supports_long_text? ? subject : nil,
        body: signed_body, status: "queued"
      )
      MessageDeliveryJob.perform_later(message.id)
      message
    end
    raise ArgumentError, "The customer has no address for the selected provider." if created.empty?

    render json: { success: true, messages: created.map { |message| message_row(message) } }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  private

  def requested_channels(key)
    key == "all" ? Messaging.enabled_channels : Array(Messaging.channel(key)).select(&:enabled?)
  end

  def message_row(message)
    {
      "id" => message.id,
      "direction" => message.direction,
      "channel" => message.channel,
      "channel_label" => Messaging.channel(message.channel)&.label || message.channel,
      "subject" => message.subject,
      "body" => message.body,
      "status" => message.status,
      "created_at" => message.created_at&.strftime("%Y-%m-%d %H:%M:%S")
    }
  end
end
