require "test_helper"

# Secondary and background brand colours: settings, page emission, save.
class BrandColorsTest < ActionDispatch::IntegrationTest
  test "seeds default the secondary and background colours" do
    seeds = Rails.root.join("db/seeds.rb").read
    assert_match(/"company_secondary_color" => "#dd2a5c"/, seeds)
    assert_match(/"company_background_color" => "#f2f6fa"/, seeds)
  end

  test "booking page emits the three brand colour variables" do
    Setting.set("company_color", "#39824f")
    Setting.set("company_secondary_color", "#dd2a5c")
    Setting.set("company_background_color", "#f2f6fa")
    get "/"
    assert_match "--oa-primary: #39824f", response.body
    assert_match "--oa-secondary: #dd2a5c", response.body
    assert_match "--oa-background: #f2f6fa", response.body
  end

  test "backend pages emit the variables too" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/calendar"
    assert_match "--oa-secondary:", response.body
    assert_match "--oa-background:", response.body
  end

  test "theme settings page offers and saves the theme and colours" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/theme_settings"
    assert_select "select[data-field=theme]"
    assert_select "input[data-field=company_color]"
    assert_select "input[data-field=company_secondary_color]"
    assert_select "input[data-field=company_background_color]"
    # No reset button and no hint line under the company colour.
    assert_select "#reset-company-color", false
    assert_select "#theme-settings form .form-text", count: 0

    post "/theme_settings/save", params: {
      theme_settings: [
        { name: "theme", value: "coder" },
        { name: "company_secondary_color", value: "#123456" },
        { name: "company_background_color", value: "#fefefe" }
      ]
    }
    assert_response :success
    assert_equal "coder", Setting.get("theme")
    assert_equal "#123456", Setting.get("company_secondary_color")
    assert_equal "#fefefe", Setting.get("company_background_color")
  end

  test "the theme page ships the accessibility panel and suggestions" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/theme_settings"
    assert_select "#color-accessibility"
    assert_select "button.apply-suggested-colors", 2
    assert_match "theme_suggestions", response.body
  end

  test "the settings nav lists Theme between Booking Settings and Business Logic" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/general_settings"
    assert_select "#settings-nav a[href='/theme_settings']"
    booking = response.body.index('href="/booking_settings"')
    theme = response.body.index('href="/theme_settings"')
    business = response.body.index('href="/business_settings"')
    assert booking < theme && theme < business, "Theme nav item is not between Booking Settings and Business Logic"
  end

  test "general settings no longer accepts the theme and colour settings" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    Setting.set("theme", "nice")
    Setting.set("company_color", "#39824f")
    post "/general_settings/save", params: {
      general_settings: [
        { name: "theme", value: "material" },
        { name: "company_color", value: "#000001" }
      ]
    }
    assert_response :success
    assert_equal "nice", Setting.get("theme")
    assert_equal "#39824f", Setting.get("company_color")
  end

  test "the colour labels exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[secondary_color background_color apply_suggested_colors color_contrast_ok
         contrast_warning_button_text contrast_warning_primary_background
         contrast_warning_secondary contrast_warning_body_background].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
