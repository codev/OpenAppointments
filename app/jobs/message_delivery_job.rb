# Delivers one queued Message via its channel adapter. Failures are recorded on
# the row and never raised (EA behaviour: log and move on).
class MessageDeliveryJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message && message.status == "queued"

    adapter = Messaging.channel(message.channel)
    raise "unknown channel #{message.channel}" unless adapter

    restriction = Messaging.country_restriction_error(message.channel, message.to_address)
    raise restriction if restriction

    redirect_for_debug(message)
    adapter.deliver(message)
    message.update!(status: "sent", error: nil)
  rescue StandardError => e
    Rails.logger.error("Messages - delivery of message #{message_id} failed: #{e.message}")
    message&.update!(status: "failed", error: e.message.truncate(255))
    alert_failure(message) if message
  end

  private

  # Debug on Messages > Settings: the row itself is rewritten so the Messages
  # log shows where it really went, the original recipient marked in the body.
  def redirect_for_debug(message)
    return unless Messaging.debug?

    intercept = Messaging.intercept_address(message.channel)
    return if intercept.nil? || message.to_address == intercept

    message.update!(to_address: intercept, body: Messaging.mark_original_to(message.body, message.to_address))
  end

  # Optional email to the maintainer; never lets an alert problem mask the failure.
  def alert_failure(message)
    return unless Setting.get("messages_failure_alert") == "1"

    AlertMailer.message_failed(message).deliver_later
  rescue StandardError => e
    Rails.logger.error("Messages - failure alert for message #{message.id} not sent: #{e.message}")
  end
end
