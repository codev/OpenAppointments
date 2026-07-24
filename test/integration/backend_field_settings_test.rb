require "test_helper"

# The customers page and the appointments modal's customer section respect the
# booking form display/require field settings.
class BackendFieldSettingsTest < ActionDispatch::IntegrationTest
  setup do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "customers page hides fields with display off" do
    Setting.set("display_email", "1")
    Setting.set("display_city", "0")
    Setting.set("display_zip_code", "0")
    get "/customers"
    assert_select "#email"
    assert_select "#city", false
    assert_select "#zip-code", false
  end

  test "customers page only marks fields required when the flag is on" do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")
    Setting.set("require_email", "0")
    Setting.set("require_phone_number", "1")
    get "/customers"
    assert_select "#email.required", false
    assert_select "label[for=email] span.text-danger", false
    assert_select "#phone-number.required"
    assert_select "label[for=phone-number] span.text-danger"
  end

  test "appointments modal hides fields with display off" do
    Setting.set("display_address", "0")
    Setting.set("display_email", "1")
    get "/calendar"
    assert_select "#appointments-modal #address", false
    assert_select "#appointments-modal #email"
  end

  test "appointments modal only marks fields required when the flag is on" do
    Setting.set("display_email", "1")
    Setting.set("require_email", "0")
    get "/calendar"
    assert_select "#appointments-modal #email.required", false
    assert_select "#appointments-modal label[for=email] span.text-danger", false

    Setting.set("require_email", "1")
    get "/calendar"
    assert_select "#appointments-modal #email.required"
    assert_select "#appointments-modal label[for=email] span.text-danger"
  end

  test "customer notes stays visible regardless of the booking notes flag" do
    Setting.set("display_notes", "0")
    get "/customers"
    assert_select "#notes"
  end
end
