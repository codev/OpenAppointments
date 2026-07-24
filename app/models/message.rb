# One outgoing or incoming message on any channel. Doubles as the Messages log
# and the per-customer conversation; customer_id nil marks an unknown sender.
class Message < ApplicationRecord
  DIRECTIONS = %w[outgoing incoming].freeze
  STATUSES = %w[queued sent failed received].freeze

  belongs_to :customer, class_name: "User", optional: true
  belongs_to :sent_by, class_name: "User", optional: true
  belongs_to :appointment, optional: true
  belongs_to :notification, optional: true

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :channel, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :outgoing, -> { where(direction: "outgoing") }
  scope :incoming, -> { where(direction: "incoming") }
  scope :unread, -> { incoming.where(read_at: nil) }
  scope :unknown_sender, -> { where(customer_id: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.unread_counts_for(customer_ids)
    unread.where(customer_id: customer_ids).group(:customer_id).count
  end

  def self.mark_read_for_customer(customer_id)
    unread.where(customer_id: customer_id).update_all(read_at: Time.current)
  end

  def self.mark_unknown_read
    unread.unknown_sender.update_all(read_at: Time.current)
  end
end
