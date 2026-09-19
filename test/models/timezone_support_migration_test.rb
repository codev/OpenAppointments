require "test_helper"

# Existing installs carry the old Fixed timezone switch across, inverted.
class TimezoneSupportMigrationTest < ActiveSupport::TestCase
  MIGRATION = Rails.root.glob("db/migrate/*_replace_fixed_timezone_with_timezone_support.rb").first

  def migrate
    require MIGRATION
    ActiveRecord::Migration.suppress_messages { ReplaceFixedTimezoneWithTimezoneSupport.new.up }
    Rails.cache.clear
  end

  test "a fixed install becomes timezone support off" do
    Setting.set("fixed_timezone", "1")
    migrate
    assert_equal "0", Setting.get("timezone_support")
    assert_nil Setting.find_by(name: "fixed_timezone")
  end

  test "an unfixed install becomes timezone support on" do
    Setting.set("fixed_timezone", "0")
    migrate
    assert_equal "1", Setting.get("timezone_support")
  end

  test "an install without the old setting is on, and running twice keeps the value" do
    Setting.where(name: %w[fixed_timezone timezone_support]).delete_all
    migrate
    assert_equal "1", Setting.get("timezone_support")
    Setting.set("timezone_support", "0")
    migrate
    assert_equal "0", Setting.get("timezone_support")
  end
end
