# One outgoing or incoming message on any channel. Doubles as the Messages log
# and the per-customer conversation; customer_id nil marks an unknown sender.
class Message < ApplicationRecord
  DIRECTIONS = %w[outgoing incoming].freeze
  # Outgoing: queued, sent (the provider accepted it), delivered (the provider
  # reported receipt) or failed, at any point. Incoming: received.
  STATUSES = %w[queued sent delivered failed received].freeze

  belongs_to :customer, class_name: "User", optional: true
  belongs_to :sent_by, class_name: "User", optional: true
  belongs_to :appointment, optional: true
  belongs_to :notification, optional: true
  belongs_to :done_by, class_name: "User", optional: true

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :channel, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :outgoing, -> { where(direction: "outgoing") }
  scope :incoming, -> { where(direction: "incoming") }
  scope :unread, -> { incoming.where(read_at: nil) }
  scope :unknown_sender, -> { where(customer_id: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :done, -> { where.not(done_at: nil) }
  scope :not_done, -> { where(done_at: nil) }
  # Incoming messages matched to a customer: the ones Move applies to.
  scope :inbox, -> { incoming.where.not(customer_id: nil) }

  # The activity log sees a message when it arrives or once sending is settled.
  after_create_commit -> { Activity.message_event(self) }, if: -> { direction == "incoming" }
  after_update_commit -> { Activity.message_event(self) }, if: -> { saved_change_to_status? && %w[sent failed].include?(status) }

  def read? = read_at.present?

  def mark_read! = update!(read_at: read_at || Time.current)

  def done? = done_at.present?

  # Done takes the message out of the Inbox (never out of the customer
  # history) and counts as read; Undo keeps it read.
  def mark_done!(user)
    update!(done_at: Time.current, done_by: user, read_at: read_at || Time.current)
  end

  def undo_done! = update!(done_at: nil, done_by: nil)

  # Other customers using the contact this incoming message came from; an
  # admin can move the message to one of them.
  def other_customers_on_contact
    return [] if customer_id.nil? || from_address.blank?

    contact = from_address.include?("@") ? { email: from_address } : { phone: from_address }
    User.customers_by_contact(**contact).reject { |customer| customer.id == customer_id }
  end

  def self.unread_counts_for(customer_ids)
    unread.where(customer_id: customer_ids).group(:customer_id).count
  end

  # A provider's report on an outgoing message, found by the id it gave us.
  # A report is applied only when it moves the message forward: delivered
  # after sent, failed at any point; a replayed or older report is ignored.
  def self.apply_provider_report(channel, provider_message_id, status, error: nil)
    message = outgoing.find_by(channel: channel, provider_message_id: provider_message_id.presence)
    return nil unless message
    return message if status == "sent" || message.status == status || (status == "delivered" && message.status != "sent")

    message.update!(status: status, error: error.presence&.truncate(255))
    message
  end

  def self.mark_read_for_customer(customer_id)
    unread.where(customer_id: customer_id).update_all(read_at: Time.current)
  end
end
