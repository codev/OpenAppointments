# Customer page messages section: conversation listing, manual sends over one
# or all enabled providers, and marking a conversation read.
class CustomerMessagesController < ApplicationController
  include BackendPage

  before_action :require_session

  # How many older messages one Load more fetches.
  PAGE = 20

  # POST /customer_messages/find: the latest window of the conversation, oldest
  # first, or with before_id the PAGE messages older than that one. "more"
  # tells the page whether a Load more button is needed.
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :customers)

    customer_id = params.require(:customer_id).to_i
    raise ArgumentError, "Invalid customer ID provided." unless customer_id.positive?
    return head :forbidden unless customer_access?(customer_id)

    history = Message.where(customer_id: customer_id)
    before_id = params[:before_id].to_i
    messages = if before_id.positive?
      history.where("id < ?", before_id).newest_first.limit(PAGE).to_a
    else
      opening_window(history, customer_id)
    end
    more = messages.any? && history.where("id < ?", messages.last.id).exists?
    render json: { messages: messages.reverse.map { |message| message_row(message) }, more: more }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /customer_messages/mark_read: every incoming message of the customer.
  def mark_read
    raise ArgumentError, "Forbidden" if cannot?(:view, :customers)

    customer_id = params.require(:customer_id).to_i
    return head :forbidden unless customer_access?(customer_id)

    Message.mark_read_for_customer(customer_id)
    render json: { success: true, inbox_count: inbox_badge_count }
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

  # The messages since the customer's most recent appointment, so the thread
  # opens on the current conversation; the latest PAGE when there is no past
  # appointment or nothing was sent since it. Newest first; callers reverse.
  # start_datetime is the provider's wall clock, created_at the server's, so
  # the appointment is picked on the business clock and its start converted
  # to an absolute time before it meets created_at.
  def opening_window(history, customer_id)
    latest = Appointment.appointments.where(id_users_customer: customer_id)
                        .where("start_datetime <= ?", BookingWindows.wall_clock_now)
                        .order(start_datetime: :desc).first
    since = latest ? history.where("created_at >= ?", BookingWindows.starts_at(latest)).newest_first.to_a : []
    since.presence || history.newest_first.limit(PAGE).to_a
  end

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
      "read" => message.direction != "incoming" || message.read?,
      "created_at" => message.created_at && DateDisplay.format_time_brief(message.created_at)
    }
  end
end
