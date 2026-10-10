class User < ApplicationRecord
  belongs_to :role, foreign_key: :id_roles
  has_one_attached :picture
  scope :display_order, -> { order(Arel.sql("users.sort_order IS NULL, users.sort_order"), :name, :email) }
  has_one_attached :picture_padded
  has_one_attached :picture_zoomed
  has_one :settings, class_name: "UserSetting", foreign_key: :id_users,
                     inverse_of: :user, dependent: :destroy, autosave: true

  # The timezone everything runs in for this user: the default without timezone
  # support, else the stored one, the default, then UTC.
  def effective_timezone
    return Setting.get("default_timezone", "UTC") unless Setting.timezone_support?

    timezone.presence || Setting.get("default_timezone", "UTC")
  end


  # Provider associations
  has_many :provider_service_links, class_name: "ServiceProviderLink", foreign_key: :id_users,
                                    inverse_of: :provider, dependent: :delete_all
  has_many :services, through: :provider_service_links
  has_many :provider_appointments, class_name: "Appointment", foreign_key: :id_users_provider,
                                   inverse_of: :provider, dependent: :destroy
  has_many :working_plan_exceptions, foreign_key: :id_users_provider,
                                     inverse_of: :provider, dependent: :destroy

  # Customer associations
  has_many :customer_appointments, class_name: "Appointment", foreign_key: :id_users_customer,
                                   inverse_of: :customer, dependent: :destroy

  # Assistant associations
  has_many :assistant_provider_links, class_name: "AssistantProviderLink", foreign_key: :id_users_assistant,
                                      inverse_of: :assistant, dependent: :delete_all
  has_many :providers, through: :assistant_provider_links

  validates :name, presence: true
  validates :email, presence: true, unless: -> { role&.slug == Role::CUSTOMER && email.blank? }

  scope :admins, -> { joins(:role).where(roles: { slug: Role::ADMIN }) }
  scope :providers, -> { joins(:role).where(roles: { slug: Role::PROVIDER }) }
  scope :assistants, -> { joins(:role).where(roles: { slug: Role::ASSISTANT }) }
  scope :customers, -> { joins(:role).where(roles: { slug: Role::CUSTOMER }) }

  # Phones are stored in E.164 (normalised on save), so a lookup is an exact
  # match on either indexed column.
  PHONE_MATCH = "users.phone_number IN (:numbers) OR users.mobile_number IN (:numbers)".freeze

  before_validation :normalize_phones
  before_create -> { self.booking_slug ||= BookingSlug.unique_for(User) if provider? }

  # Customers who use this email (any case) or phone, once each. Partners and
  # family may share one.
  def self.customers_by_contact(email: nil, phone: nil) = customers_by_contacts(emails: [ email ], phones: [ phone ])

  # Customers who use any of these emails or phones, once each: one query for
  # the emails and one for the phones.
  def self.customers_by_contacts(emails: [], phones: [])
    emails = emails.compact_blank.map(&:downcase).uniq
    phones = phones.filter_map { |phone| Messaging::Template.e164(phone) }.select { |phone| phone.length >= 7 }.uniq
    found = emails.any? ? customers.where("LOWER(email) IN (?)", emails).to_a : []
    # By id from a phone-only subquery: SQLite then searches the phone indexes
    # instead of every user with the customer role.
    found += customers.where(id: User.unscoped.where(PHONE_MATCH, numbers: phones).select(:id)).to_a if phones.any?
    found.uniq
  end

  # Whether this email or phone is one of the customer's, compared as the
  # lookups above compare.
  def uses_contact?(address)
    return email.to_s.downcase == address.downcase if address.include?("@")

    [ phone_number, mobile_number ].include?(Messaging::Template.e164(address))
  end

  # Of customers sharing a contact, the one a message from it most likely
  # comes from: the next upcoming appointment, else the latest past one, else
  # the most recently updated customer.
  def self.likely_sender(candidates, now = Time.current)
    return candidates.first if candidates.size < 2

    upcoming, latest = Appointment.next_and_latest(Appointment.appointments.active.where(id_users_customer: candidates.map(&:id)), now)
    id = (upcoming || latest)&.id_users_customer
    id ? candidates.find { |customer| customer.id == id } : candidates.max_by(&:updated_at)
  end

  # The customer a booking belongs to: the same email or phone and the same
  # name. People sharing contact details keep their own records.
  def self.customer_for_booking(email:, phone:, name:)
    wanted = customer_keys(name, email, phone)
    customers_by_contact(email: email, phone: phone).find { |customer| customer.customer_keys.intersect?(wanted) }
  end

  # "name|contact" for each email and phone: two records with a key in common
  # are the same customer. Bookings and the 10to8 import both match on these.
  def self.customer_keys(name, email, *phones)
    name = name.to_s.squish.downcase
    return [] if name.blank?

    contacts = phones.filter_map { |phone| Messaging::Template.e164(phone).presence }
    contacts.unshift(email.downcase) if email.present?
    contacts.map { |contact| "#{name}|#{contact}" }
  end

  def customer_keys = User.customer_keys(name, email, phone_number, mobile_number)

  def admin? = role.slug == Role::ADMIN
  def provider? = role.slug == Role::PROVIDER
  def assistant? = role.slug == Role::ASSISTANT
  def customer? = role.slug == Role::CUSTOMER

  def full_name = name

  def working_plan
    raw = settings&.working_plan
    raw.present? ? JSON.parse(raw) : nil
  end

  private

  def normalize_phones
    self.phone_number = Messaging::Template.e164(phone_number) if phone_number_changed?
    self.mobile_number = Messaging::Template.e164(mobile_number) if mobile_number_changed?
  end
end
