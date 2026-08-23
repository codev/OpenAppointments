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
    get "/customers/new"
    assert_select "#customer_email"
    assert_select "#customer_city", false
    assert_select "#customer_zip_code", false
  end

  test "customers page only marks fields required when the flag is on" do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")
    Setting.set("require_email", "0")
    Setting.set("require_phone_number", "1")
    get "/customers/new"
    assert_select "#customer_email[required]", false
    assert_select "label[for=customer_email] span.text-danger", false
    assert_select "#customer_phone_number[required]"
    assert_select "label[for=customer_phone_number] span.text-danger"
  end

  test "appointment form hides fields with display off" do
    Setting.set("display_address", "0")
    Setting.set("display_email", "1")
    get "/appointments/new"
    assert_select "#appointment-form #address", false
    assert_select "#appointment-form #email"
  end

  test "appointment form only marks fields required when the flag is on" do
    Setting.set("display_email", "1")
    Setting.set("require_email", "0")
    get "/appointments/new"
    assert_select "#appointment-form #email[required]", false
    assert_select "#appointment-form label[for=email] span.text-danger", false

    Setting.set("require_email", "1")
    get "/appointments/new"
    assert_select "#appointment-form #email[required]"
    assert_select "#appointment-form label[for=email] span.text-danger"
  end

  test "customer notes stays visible regardless of the booking notes flag" do
    Setting.set("display_notes", "0")
    get "/customers/new"
    assert_select "#customer_notes"
  end
end
