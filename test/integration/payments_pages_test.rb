require "test_helper"

# Payments panel: Settings (global switch and default method) and the Methods
# cards, admin only, linked from the settings menu.
class PaymentsPagesTest < ActionDispatch::IntegrationTest
  PAGES = %w[payments_settings payments_methods].freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  test "admin can view every payments page" do
    login_admin
    PAGES.each do |page|
      get "/#{page}"
      assert_response :success, "expected 200 for admin on /#{page}"
    end
  end

  test "provider is forbidden and anonymous users are sent to login" do
    login_provider
    PAGES.each do |page|
      get "/#{page}"
      assert_response :forbidden, "expected 403 for provider on /#{page}"
    end
    reset!
    get "/payments_settings"
    assert_redirected_to "/login"
  end

  test "the settings menu links to Payments" do
    login_admin
    get "/calendar"
    assert_select ".dropdown-menu a.dropdown-item[href='/payments_settings']", text: /Payments/
  end

  test "the settings page saves the switch and the default method" do
    login_admin
    get "/payments_settings"
    assert_select "#payments-nav a[href='/payments_methods']"
    assert_select "input#payments-enabled[name='settings[payments_enabled]']"
    assert_select "select#payments-default-method option[value='in_person']"

    post "/payments_settings/save", params: { settings: { payments_enabled: "1", payments_default_method: "in_person" } }
    assert_redirected_to "/payments_settings"
    assert_equal "1", Setting.get("payments_enabled")
    assert_equal "in_person", Setting.get("payments_default_method")

    post "/payments_settings/save", params: { settings: { payments_default_method: "paypal" } }
    assert_equal "in_person", Setting.get("payments_default_method"), "an unknown method is ignored"
  end

  test "the methods page shows a card per method with its state and a Configure link" do
    Setting.set("payments_stripe_enabled", "1")
    Setting.set("payments_stripe_secret_key", "sk_test_1")
    login_admin
    get "/payments_methods"
    assert_select "#payments-methods .card", 3
    assert_select ".card", text: /Pay in person/ do
      assert_select ".badge", text: "Default"
      assert_select "a[href='/payments_in_person_settings']", text: /Configure/
    end
    assert_select ".card", text: /Bank transfer/ do
      assert_select ".badge", text: "Disabled"
    end
    assert_select ".card", text: /Stripe/ do
      assert_select ".badge", text: "Active"
      assert_select "a[href='/payments_stripe_settings']"
    end
  end
end
