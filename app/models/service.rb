class Service < ApplicationRecord
  belongs_to :category, class_name: "ServiceCategory", foreign_key: :id_service_categories, optional: true
  has_one_attached :picture
  has_one_attached :picture_padded
  has_one_attached :picture_zoomed
  has_many :provider_links, class_name: "ServiceProviderLink", foreign_key: :id_services,
                            inverse_of: :service, dependent: :delete_all
  has_many :providers, through: :provider_links
  has_many :appointments, foreign_key: :id_services, dependent: :destroy

  validates :name, presence: true
  validates :duration, numericality: { greater_than_or_equal_to: Appointment::EVENT_MINIMUM_DURATION }, allow_nil: true

  scope :available, -> { where(is_private: false) }
  scope :display_order, -> { order(Arel.sql("services.sort_order IS NULL, services.sort_order"), :name) }

  before_create -> { self.booking_slug ||= BookingSlug.unique_for(Service) }
end
