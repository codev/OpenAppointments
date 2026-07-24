require "test_helper"

class BookingWizardOrderTest < ActionDispatch::IntegrationTest
  test "default order is service first then provider" do
    get "/"
    assert_response :success
    assert_select "#wizard-frame-1 #select-service"
    assert_select "#wizard-frame-2 #select-provider"
    assert_select "#wizard-frame-3 #select-date"
    assert_select "#wizard-frame-4 #name"
    assert_select "#wizard-frame-5 #book-appointment-submit"
    assert_select "#steps #step-5"
  end

  test "first=provider swaps the two selection pages" do
    get "/", params: { first: "provider" }
    assert_response :success
    assert_select "#wizard-frame-1 #select-provider"
    assert_select "#wizard-frame-2 #select-service"
  end

  test "an unknown first value falls back to service first" do
    get "/", params: { first: "bogus" }
    assert_select "#wizard-frame-1 #select-service"
  end

  test "booking_provider_first setting makes provider the first page" do
    Setting.set("booking_provider_first", "1")
    get "/"
    assert_select "#wizard-frame-1 #select-provider"
    assert_select "#wizard-frame-2 #select-service"

    # The URL parameter still overrides the setting in both directions.
    get "/", params: { first: "service" }
    assert_select "#wizard-frame-1 #select-service"
  end

  test "display_order_switch off hides the swap link but keeps the URL swap" do
    Setting.set("display_order_switch", "0")
    get "/"
    assert_select "a.swap-first-step", false

    get "/", params: { first: "provider" }
    assert_select "#wizard-frame-1 #select-provider"
  end

  test "display_powered_by off hides the powered by credit" do
    get "/"
    assert_match "Powered By", response.body

    Setting.set("display_powered_by", "0")
    get "/"
    assert_no_match(/Powered By/, response.body)
  end

  test "the wizard option keys exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[booking_provider_first display_order_switch display_powered_by].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end

  test "swap links point at the other ordering" do
    get "/"
    assert_select "#wizard-frame-1 a.swap-first-step[href*='first=provider']",
                  text: I18n.t("ea.select_provider_first")

    get "/", params: { first: "provider" }
    assert_select "#wizard-frame-1 a.swap-first-step[href*='first=service']",
                  text: I18n.t("ea.select_service_first")
  end

  test "the js payload carries the first step" do
    get "/"
    assert_match(/"first_step":"service"/, response.body)
    get "/", params: { first: "provider" }
    assert_match(/"first_step":"provider"/, response.body)
  end

  test "manage mode still renders the wizard" do
    appointment = appointments(:upcoming)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      get "/booking/reschedule/#{appointment.booking_hash}"
    end
    assert_response :success
    assert_select "#wizard-frame-1 #select-service"
    assert_no_match(/swap-first-step/, response.body)
  end

  test "new wizard strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[select_provider_first select_service_first].each do |key|
        value = I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil)
        assert value.present?, "missing ea.#{key} in #{locale}"
      end
    end
  end
end
