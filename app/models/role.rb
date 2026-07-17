class Role < ApplicationRecord
  PRIV_VIEW = 1
  PRIV_ADD = 2
  PRIV_EDIT = 4
  PRIV_DELETE = 8

  ADMIN = "admin"
  PROVIDER = "provider"
  SECRETARY = "secretary"
  CUSTOMER = "customer"

  RESOURCES = %w[appointments customers services users system_settings user_settings webhooks blocked_periods].freeze

  # No has_many :users here: the permission bitmask column `users` owns that name.
  validates :slug, presence: true, uniqueness: true

  def can?(action, resource)
    resource = resource.to_s
    raise ArgumentError, "unknown resource: #{resource}" unless RESOURCES.include?(resource)

    mask = self[resource].to_i
    bit = { view: PRIV_VIEW, add: PRIV_ADD, edit: PRIV_EDIT, delete: PRIV_DELETE }.fetch(action.to_sym)
    mask & bit == bit
  end

  # EA Roles_model::get_permissions_by_slug shape: {resource => {view:, add:, edit:, delete:}}
  def permissions
    RESOURCES.index_with do |resource|
      { view: can?(:view, resource), add: can?(:add, resource),
        edit: can?(:edit, resource), delete: can?(:delete, resource) }
    end
  end
end
