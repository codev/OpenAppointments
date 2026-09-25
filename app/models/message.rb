# One outgoing or incoming message on any channel. Doubles as the Messages log
# and the per-customer conversation; customer_id nil marks an unknown sender.
class Message < ApplicationRecord
  DIRECTIONS = %w[outgoing incoming].freeze
  STATUSES = %w[queued sent failed received].freeze

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
  # The admin Inbox: incoming messages from known customers.
  scope :inbox, -> { incoming.where.not(customer_id: nil) }

  def read? = read_at.present?

  def mark_read! = update!(read_at: read_at || Time.current)

  def done? = done_at.present?

  # Done takes the message out of the Inbox (never out of the customer
  # history) and counts as read; Undo keeps it read.
  def mark_done!(user)
    update!(done_at: Time.current, done_by: user, read_at: read_at || Time.current)
  end

  def undo_done! = update!(done_at: nil, done_by: nil)

  def self.unread_counts_for(customer_ids)
    unread.where(customer_id: customer_ids).group(:customer_id).count
  end

  def self.mark_read_for_customer(customer_id)
    unread.where(customer_id: customer_id).update_all(read_at: Time.current)
  end
end
