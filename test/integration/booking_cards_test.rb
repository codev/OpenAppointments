require "test_helper"

class BookingCardsTest < ActionDispatch::IntegrationTest
  test "dropdown mode is the default" do
    get "/"
    assert_response :success
    assert_select "#category-cards", false
    assert_select "#select-service:not(.d-none)"
  end

  test "cards mode renders category cards revealing service cards" do
    Setting.set("booking_display_mode", "cards")
    get "/"
    assert_response :success
    assert_select "#category-cards .booking-card", minimum: 1
    assert_select ".service-cards .booking-card .card-title", text: services(:haircut).name
    assert_select "#wizard-frame-1 #select-service.d-none"
    assert_select "#provider-cards"
    assert_select "#wizard-frame-2 #select-provider.d-none"
  end

  test "cards show the picture when attached" do
    Setting.set("booking_display_mode", "cards")
    services(:haircut).picture.attach(fixture_file_upload("picture.png", "image/png"))
    get "/"
    assert_select ".service-cards .booking-card img.card-img-top"
  end

  test "booking settings page saves the display mode" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    post "/booking_settings/save", params: {
      csrf_token: "x",
      booking_settings: [ { name: "booking_display_mode", value: "cards" } ]
    }
    assert_response :success
    assert_equal "cards", Setting.get("booking_display_mode")
  end

  test "new display mode strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[booking_display_mode display_as_dropdown display_as_cards picture remove_picture].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
