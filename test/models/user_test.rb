require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "role scopes" do
    assert_includes User.admins, users(:admin)
    assert_includes User.providers, users(:zane)
    assert_includes User.secretaries, users(:sam)
    assert_includes User.customers, users(:jx)
    assert_not_includes User.providers, users(:jx)
  end

  test "role predicates" do
    assert users(:admin).admin?
    assert users(:zane).provider?
    assert users(:sam).secretary?
    assert users(:jx).customer?
  end

  test "full_name joins names" do
    assert_equal "Zane", users(:zane).full_name
  end

  test "working_plan parses JSON from user settings" do
    plan = users(:zane).working_plan
    assert_equal "09:00", plan["monday"]["start"]
    assert_equal [ { "start" => "14:30", "end" => "15:00" } ], plan["monday"]["breaks"]
    assert_nil plan["wednesday"]
  end

  test "working_plan nil without settings" do
    assert_nil users(:jx).working_plan
  end

  test "destroying user destroys settings row" do
    assert_difference "UserSetting.count", -1 do
      users(:zane).destroy
    end
  end

  test "requires first and last name" do
    user = User.new(role: roles(:customer), email: "x@example.org")
    assert_not user.valid?
    assert user.errors[:name].any?
  end
end
