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

  test "rich text settings are sanitised whichever path writes them" do
    Setting.set("booking_notice_content", '<p style="text-align: center; background: url(javascript:x)">Hi</p><script>alert(1)</script><img src=x onerror=alert(1)>')
    assert_equal '<p style="text-align:center;">Hi</p>alert(1)<img src="x">', Setting.get("booking_notice_content")
    Setting.set("company_name", "<b>Kept</b>")
    assert_equal "<b>Kept</b>", Setting.get("company_name")
  end

  test "name is unique" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Setting.create!(name: "company_name", value: "Duplicate")
    end
  end
end
