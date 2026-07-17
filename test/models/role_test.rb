require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "admin has full permissions on every resource" do
    admin = roles(:admin)
    Role::RESOURCES.each do |resource|
      %i[view add edit delete].each do |action|
        assert admin.can?(action, resource), "admin should #{action} #{resource}"
      end
    end
  end

  test "provider bitmask decodes per EA seed values" do
    provider = roles(:provider)
    assert provider.can?(:view, :appointments)
    assert provider.can?(:delete, :appointments)
    assert provider.can?(:edit, :customers)
    assert_not provider.can?(:view, :services)
    assert_not provider.can?(:view, :system_settings)
    assert_not provider.can?(:add, :webhooks)
    assert_not provider.can?(:view, :blocked_periods)
  end

  test "customer has no permissions" do
    customer = roles(:customer)
    Role::RESOURCES.each do |resource|
      assert_not customer.can?(:view, resource)
    end
  end

  test "partial bitmask decodes each bit independently" do
    role = Role.new(appointments: Role::PRIV_VIEW | Role::PRIV_EDIT)
    assert role.can?(:view, :appointments)
    assert role.can?(:edit, :appointments)
    assert_not role.can?(:add, :appointments)
    assert_not role.can?(:delete, :appointments)
  end

  test "permissions returns EA-shaped nested hash" do
    perms = roles(:secretary).permissions
    assert_equal Role::RESOURCES.sort, perms.keys.sort
    assert_equal({ view: true, add: true, edit: true, delete: true }, perms["appointments"])
    assert_equal({ view: false, add: false, edit: false, delete: false }, perms["webhooks"])
  end

  test "unknown resource raises" do
    assert_raises(ArgumentError) { roles(:admin).can?(:view, :nonexistent) }
  end
end
