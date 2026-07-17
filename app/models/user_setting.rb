class UserSetting < ApplicationRecord
  self.primary_key = :id_users

  belongs_to :user, foreign_key: :id_users, inverse_of: :settings

  validates :username, uniqueness: true, allow_nil: true
end
