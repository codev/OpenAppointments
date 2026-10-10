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

  attr_writer :other_customers_on_contact

  # Other customers using the contact this incoming message came from; an
  # admin can move the message to one of them. Preloaded for an Inbox page.
  def other_customers_on_contact
    @other_customers_on_contact || Message.find_other_customers([ self ]).first
  end

  # One customer lookup for a page of messages instead of one per row.
  def self.preload_other_customers(messages)
    messages.zip(find_other_customers(messages)) { |message, others| message.other_customers_on_contact = others }
  end

  # For each message, the other customers using the contact it came from.
  def self.find_other_customers(messages)
    linked = messages.select { |message| message.customer_id && message.from_address.present? }
    emails, phones = linked.map(&:from_address).partition { |address| address.include?("@") }
    candidates = linked.any? ? User.customers_by_contacts(emails: emails, phones: phones) : []
    messages.map do |message|
      next [] unless linked.include?(message)

      candidates.select { |customer| customer.id != message.customer_id && customer.uses_contact?(message.from_address) }
    end
  end

  def self.unread_counts_for(customer_ids)
    unread.where(customer_id: customer_ids).group(:customer_id).count
  end

  def self.mark_read_for_customer(customer_id)
    unread.where(customer_id: customer_id).update_all(read_at: Time.current)
  end
end
