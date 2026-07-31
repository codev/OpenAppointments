require "test_helper"

class CustomCssTest < ActionDispatch::IntegrationTest
  test "custom css renders on booking, backend and account pages, breakouts stripped" do
    get "/"
    assert_not_includes response.body, "booking-card-flair"

    Setting.set("custom_css", ".booking-card-flair { color: red; }</style><script>alert(1)</script>")
    get "/"
    assert_includes response.body, ".booking-card-flair { color: red; }"
    assert_not_includes response.body, "</style><script>alert(1)</script>"

    get "/login"
    assert_includes response.body, ".booking-card-flair { color: red; }"

    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/calendar"
    assert_includes response.body, ".booking-card-flair { color: red; }"
  end

  test "the theme page has the box and save persists the css across theme changes" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/theme_settings"
    assert_select "textarea#custom-css[data-field=custom_css]"
    assert_select "#theme-settings-page", text: /#{I18n.t('ea.custom_css_hint')}/

    post "/theme_settings/save", params: {
      theme_settings: [ { name: "custom_css", value: "body { letter-spacing: 1px; }" } ]
    }
    assert_response :success
    assert_equal "body { letter-spacing: 1px; }", Setting.get("custom_css")

    post "/theme_settings/save", params: { theme_settings: [ { name: "theme", value: "outline" } ] }
    assert_response :success
    assert_equal "body { letter-spacing: 1px; }", Setting.get("custom_css"),
                 "changing theme must keep the custom css"
  end

  test "the new strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[custom_css custom_css_hint select_category uncategorized category_hidden_hint].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
