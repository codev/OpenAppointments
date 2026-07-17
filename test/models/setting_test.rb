require "test_helper"

class SettingTest < ActiveSupport::TestCase
  setup { Rails.cache.clear }

  test "get returns stored value" do
    assert_equal "30", Setting.get("book_advance_timeout")
  end

  test "get returns default for missing key" do
    assert_nil Setting.get("nonexistent")
    assert_equal "fallback", Setting.get("nonexistent", "fallback")
  end

  test "set creates and updates, values stored as strings" do
    Setting.set("new_key", 42)
    assert_equal "42", Setting.get("new_key")
    Setting.set("new_key", "43")
    assert_equal "43", Setting.get("new_key")
  end

  test "set invalidates cached value" do
    assert_equal "30", Setting.get("book_advance_timeout")
    Setting.set("book_advance_timeout", "45")
    assert_equal "45", Setting.get("book_advance_timeout")
  end

  test "name is unique" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Setting.create!(name: "company_name", value: "Duplicate")
    end
  end
end
