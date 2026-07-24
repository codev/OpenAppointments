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

  test "general settings page offers and saves the two new colours" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/general_settings"
    assert_select "input[data-field=company_secondary_color]"
    assert_select "input[data-field=company_background_color]"

    post "/general_settings/save", params: {
      general_settings: [
        { name: "company_secondary_color", value: "#123456" },
        { name: "company_background_color", value: "#fefefe" }
      ]
    }
    assert_response :success
    assert_equal "#123456", Setting.get("company_secondary_color")
    assert_equal "#fefefe", Setting.get("company_background_color")
  end

  test "the settings page ships the accessibility panel and suggestions" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/general_settings"
    assert_select "#color-accessibility"
    assert_select "#apply-suggested-colors"
    assert_match "theme_suggestions", response.body
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
