class User < ApplicationRecord
  belongs_to :role, foreign_key: :id_roles
  has_one :settings, class_name: "UserSetting", foreign_key: :id_users,
                     inverse_of: :user, dependent: :destroy, autosave: true

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

  # Secretary associations
  has_many :secretary_provider_links, class_name: "SecretaryProviderLink", foreign_key: :id_users_secretary,
                                      inverse_of: :secretary, dependent: :delete_all
  has_many :providers, through: :secretary_provider_links

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, unless: -> { role&.slug == Role::CUSTOMER && email.blank? }

  scope :admins, -> { joins(:role).where(roles: { slug: Role::ADMIN }) }
  scope :providers, -> { joins(:role).where(roles: { slug: Role::PROVIDER }) }
  scope :secretaries, -> { joins(:role).where(roles: { slug: Role::SECRETARY }) }
  scope :customers, -> { joins(:role).where(roles: { slug: Role::CUSTOMER }) }

  def admin? = role.slug == Role::ADMIN
  def provider? = role.slug == Role::PROVIDER
  def secretary? = role.slug == Role::SECRETARY
  def customer? = role.slug == Role::CUSTOMER

  def full_name = [ first_name, last_name ].compact_blank.join(" ")

  def working_plan
    raw = settings&.working_plan
    raw.present? ? JSON.parse(raw) : nil
  end
end
