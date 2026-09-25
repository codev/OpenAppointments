# One message: mark read (inbox pages and the customer conversation), Done /
# Undo and Move on the admin inbox pages, and permanent delete for admins
# (customer conversation, Unknown Inbox).
class MessagesController < ApplicationController
  include BackendPage

  before_action :require_session

  # POST /messages/:id/mark_read
  def mark_read
    message = Message.incoming.find(params[:id])
    return head :forbidden unless message_access?(message)

    message.mark_read!
    render json: { success: true, inbox_unread: inbox_badge_count }
  end

  # POST /messages/:id/done. The row leaves the list it was on.
  def done
    change_done { |message| message.mark_done!(current_user) }
  end

  # POST /messages/:id/undo_done, from the Show done list.
  def undo_done
    change_done(&:undo_done!)
  end

  # POST /messages/:id/move: this message only, to another customer using its
  # contact. Sends nothing.
  def move
    return head :forbidden unless inbox_access?

    message = Message.inbox.find(params[:id])
    customer = message.other_customers_on_contact.find { |other| other.id == params[:customer_id].to_i }
    return head :unprocessable_entity unless customer

    message.update!(customer: customer)
    render turbo_stream: turbo_stream.replace("inbox-message-#{message.id}", partial: "shared/inbox_message",
                                                                             locals: { message: message, moved: true })
  end

  # DELETE /messages/:id. No soft delete: mistakes and erasure requests.
  def destroy
    return head :forbidden unless current_user&.admin?

    message = Message.find(params[:id])
    message.destroy!
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("inbox-message-#{message.id}"),
          turbo_stream.replace("inbox-unread", partial: "shared/inbox_unread", locals: { count: inbox_badge_count })
        ]
      end
      format.json { render json: { success: true, inbox_unread: inbox_badge_count } }
    end
  end

  private

  def change_done
    return head :forbidden unless inbox_access?

    message = Message.incoming.find(params[:id])
    yield message
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("inbox-message-#{message.id}"),
          turbo_stream.replace("inbox-unread", partial: "shared/inbox_unread", locals: { count: inbox_badge_count })
        ]
      end
      format.html { redirect_back fallback_location: "/inbox" }
    end
  end

  def message_access?(message)
    return inbox_access? if message.customer_id.nil?

    can?(:view, :customers) && customer_access?(message.customer_id)
  end
end
