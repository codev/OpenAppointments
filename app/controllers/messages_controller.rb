# Marking a single message read, from the inbox pages and the customer
# conversation.
class MessagesController < ApplicationController
  include BackendPage

  before_action :require_session

  # POST /messages/:id/mark_read
  def mark_read
    message = Message.incoming.find(params[:id])
    return head :forbidden unless message_access?(message)

    message.mark_read!
    render json: { success: true, inbox_unread: inbox_scope.unread.count }
  end

  private

  def message_access?(message)
    return unknown_inbox_access? if message.customer_id.nil?

    can?(:view, :customers) && customer_access?(message.customer_id)
  end
end
