class ServiceCategory < ApplicationRecord
  has_many :services, foreign_key: :id_service_categories, inverse_of: :category, dependent: :nullify
  has_one_attached :picture

  validates :name, presence: true
end
