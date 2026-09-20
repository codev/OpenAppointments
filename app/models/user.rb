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

  # Other emails and phone numbers, one per line. A customer is found by any
  # of their addresses; phones are compared in E.164 however they were typed.
  def other_email_list = split_lines(other_emails)
  def other_phone_list = split_lines(other_phones)
  def all_emails = [ email, *other_email_list ].compact_blank.map(&:downcase).uniq
  def all_phones = [ phone_number, mobile_number, *other_phone_list ].filter_map { |number| Messaging::Template.e164(number) }.uniq

  # An email or phone not already known becomes another address; a blank
  # primary takes it instead.
  def add_contact(email: nil, phone: nil)
    if email.present? && all_emails.exclude?(email.strip.downcase)
      self.email.blank? ? self.email = email.strip : self.other_emails = (other_email_list + [ email.strip ]).join("\n")
    end
    normalised = Messaging::Template.e164(phone)
    if normalised.present? && all_phones.exclude?(normalised)
      phone_number.blank? ? self.phone_number = phone.strip : self.other_phones = (other_phone_list + [ normalised ]).join("\n")
    end
    changed?
  end

  def self.customer_by_contact(email: nil, phone: nil, scope: customers)
    customer_by_email(email, scope) || customer_by_phone(phone, scope)
  end

  def self.customer_by_email(email, scope = customers)
    email = email.to_s.strip.downcase
    return nil if email.blank?

    scope.where("LOWER(email) = ?", email).first ||
      scope.where("LOWER(other_emails) LIKE ?", "%#{sanitize_sql_like(email)}%").find { |user| user.all_emails.include?(email) }
  end

  def self.customer_by_phone(number, scope = customers)
    wanted = Messaging::Template.e164(number)
    return nil if wanted.blank? || wanted.length < 7

    tail = "%#{wanted[-7..]}%"
    stripped = "REPLACE(REPLACE(REPLACE(COALESCE(%s, ''), ' ', ''), '-', ''), '(', '')"
    condition = %w[phone_number mobile_number other_phones].map { |column| "#{format(stripped, column)} LIKE :tail" }.join(" OR ")
    scope.where(condition, tail: tail).find { |user| user.all_phones.include?(wanted) }
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

  private

  def split_lines(text)
    text.to_s.split(/[\r\n]+/).map(&:strip).compact_blank.uniq
  end
end
