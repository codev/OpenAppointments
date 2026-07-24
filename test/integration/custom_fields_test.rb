require "test_helper"

# Longer text field option on custom fields + doubled notes heights.
class CustomFieldsTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "booking form renders long custom fields as full-width textareas" do
    Setting.set("display_custom_field_1", "1")
    Setting.set("long_custom_field_1", "1")
    Setting.set("display_custom_field_2", "1")
    Setting.set("display_notes", "1")

    get "/"
    assert_select "div.col-12 > textarea#custom-field-1[rows='2']"
    assert_select "div.col-12.col-lg-6 > input#custom-field-2"
    assert_select "textarea#notes[rows='2']"
  end

  test "customers page renders long custom fields at notes height" do
    Setting.set("display_custom_field_1", "1")
    Setting.set("long_custom_field_1", "1")
    login_admin
    get "/customers"
    assert_select "textarea#custom-field-1[rows='8'][disabled]"
    assert_select "textarea#notes[rows='8']"
  end

  test "booking settings offers and saves the longer text field switch" do
    login_admin
    get "/booking_settings"
    assert_select "input[data-field=long_custom_field_1]"
    assert_select "input[data-field=long_custom_field_5]"

    post "/booking_settings/save", params: {
      booking_settings: [ { name: "long_custom_field_3", value: "1" } ]
    }
    assert_response :success
    assert_equal "1", Setting.get("long_custom_field_3")
  end

  test "the longer text field label exists in every locale" do
    I18n.available_locales.each do |locale|
      assert I18n.t("ea.longer_text_field", locale: locale, fallback: false, default: nil).present?,
             "missing ea.longer_text_field in #{locale}"
    end
  end
end
