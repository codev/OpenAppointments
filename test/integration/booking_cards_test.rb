require "test_helper"

class BookingCardsTest < ActionDispatch::IntegrationTest
  test "dropdown mode is the default" do
    get "/"
    assert_response :success
    assert_select "#category-cards", false
    assert_select "#select-service:not(.d-none)"
  end

  test "cards mode starts with Select Category, services revealed per category" do
    Setting.set("booking_display_mode", "cards")
    get "/"
    assert_response :success
    assert_select "#wizard-frame-1 h2.frame-title", text: I18n.t("ea.select_category")
    assert_select "#category-cards .booking-card", minimum: 1
    assert_select "#category-cards .booking-card + .booking-card", count: 0 # sanity: one card per column div
    assert_select "#category-cards > div.col-6.col-md-3"
    assert_select "#select-service-heading.d-none", text: I18n.t("ea.select_service")
    assert_select ".service-cards.d-none .booking-card .card-title", text: services(:haircut).name
    assert_select "#wizard-frame-1 #select-service.d-none"
    assert_select "#provider-cards"
    assert_select "#wizard-frame-2 #select-provider.d-none"
  end

  test "uncategorized services show from the start with the Select Service heading" do
    Setting.set("booking_display_mode", "cards")
    loose = Service.create!(name: "Walk In Trim", duration: 15, price: 0, currency: "GBP")
    ServiceProviderLink.create!(id_services: loose.id, id_users: users(:zane).id)
    get "/"
    assert_select "#select-service-heading:not(.d-none)"
    assert_select ".service-cards[data-category-id='']:not(.d-none) .booking-card .card-title",
                  text: "Walk In Trim"
  end

  test "hidden categories and their services disappear from the booking page" do
    Setting.set("booking_display_mode", "cards")
    service_categories(:hair).update!(is_hidden: true)
    get "/"
    assert_select "#category-cards .booking-card", count: 0
    assert_select ".booking-card .card-title", text: services(:haircut).name, count: 0

    Setting.set("booking_display_mode", "dropdown")
    get "/"
    assert_select "#select-service option", text: services(:haircut).name, count: 0
  end

  test "the Select Provider First switch is a button beside Next" do
    Setting.set("display_order_switch", "1")
    get "/"
    assert_select "#wizard-frame-1 .command-buttons a.swap-first-step.btn",
                  text: /#{I18n.t('ea.select_provider_first')}/
    assert_select "#wizard-frame-1 .frame-content .swap-first-step", count: 0
  end

  test "cards show the styled picture per the picture style setting" do
    Setting.set("booking_display_mode", "cards")
    PictureVariants.attach(services(:haircut), file_fixture("picture.png").to_s,
                           filename: "picture.png", content_type: "image/png")
    get "/"
    padded_path = Rails.application.routes.url_helpers.rails_blob_path(
      services(:haircut).picture_padded, only_path: true
    )
    assert_select ".service-cards .booking-card img.card-img-top[src=?]", padded_path

    Setting.set("picture_style_services", "zoomed")
    get "/"
    zoomed_path = Rails.application.routes.url_helpers.rails_blob_path(
      services(:haircut).picture_zoomed, only_path: true
    )
    assert_select ".service-cards .booking-card img.card-img-top[src=?]", zoomed_path
  end

  test "the booking settings page offers the three picture style selects" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/booking_settings"
    %w[picture-style-categories picture-style-services picture-style-providers].each do |id|
      assert_select "select##{id} option[value=border]", text: I18n.t("ea.white_border")
      assert_select "select##{id} option[value=zoomed]", text: I18n.t("ea.zoomed")
    end
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
      %w[booking_display_mode display_as_dropdown display_as_cards picture remove_picture
         picture_styles picture_styles_hint white_border zoomed].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
