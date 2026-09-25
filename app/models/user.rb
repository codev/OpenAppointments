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

  # A loose pre-filter on the last digits of either number, with the usual
  # separators removed; the E.164 comparison in Ruby decides.
  PHONE_TAIL_MATCH = <<~SQL.squish.freeze
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(phone_number, ' ', ''), '-', ''), '(', ''), ')', ''), '.', '') LIKE :tail
    OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(mobile_number, ' ', ''), '-', ''), '(', ''), ')', ''), '.', '') LIKE :tail
  SQL

  # The customer whose phone or mobile number is this one, however either was
  # typed.
  def self.customer_by_phone(number, scope = customers)
    customers_by_phone(number, scope).first
  end

  # Customers whose phone or mobile number is this one: both sides are compared
  # in E.164 after a digits-only narrowing.
  def self.customers_by_phone(number, scope = customers)
    wanted = Messaging::Template.e164(number)
    return [] if wanted.blank? || wanted.length < 7

    scope.where(PHONE_TAIL_MATCH, tail: "%#{wanted[-7..]}%")
         .select { |user| [ user.phone_number, user.mobile_number ].any? { |stored| Messaging::Template.e164(stored) == wanted } }
  end

  # The customer a booking belongs to: the same email or phone and the same
  # name. People sharing contact details keep their own records.
  def self.customer_for_booking(email:, phone:, name:)
    candidates = email.present? ? customers.where("LOWER(email) = ?", email.downcase).to_a : []
    candidates += customers_by_phone(phone) if phone.present?
    candidates.find { |customer| same_name?(customer.name, name) }
  end

  def self.same_name?(one, other)
    one.to_s.squish.casecmp?(other.to_s.squish)
  end
  scope :assistants, -> { joins(:role).where(roles: { slug: Role::ASSISTANT }) }
  scope :customers, -> { joins(:role).where(roles: { slug: Role::CUSTOMER }) }

  before_create -> { self.booking_slug ||= BookingSlug.unique_for(User) if provider? }

  def admin? = role.slug == Role::ADMIN
  def provider? = role.slug == Role::PROVIDER
  def assistant? = role.slug == Role::ASSISTANT
  def customer? = role.slug == Role::CUSTOMER

  def full_name = name

  def working_plan
    raw = settings&.working_plan
    raw.present? ? JSON.parse(raw) : nil
  end
end
