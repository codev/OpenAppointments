require "test_helper"

class LocalizationTest < ActionDispatch::IntegrationTest
  test "all 41 EA languages are available and loaded" do
    assert_equal 41, Localization.available_languages.size
    assert_equal 41, I18n.available_locales.size
    Localization::LANGUAGES.each_key do |code|
      assert I18n.available_locales.include?(code.to_sym), "missing locale #{code}"
    end
  end

  test "translations exist for a sample of locales" do
    assert_equal "Book Appointment With", I18n.t("ea.page_title", locale: :en)
    assert_equal "Vereinbaren Sie einen Termin mit", I18n.t("ea.page_title", locale: :de)
    assert_not_equal "ea.page_title", I18n.t("ea.page_title", locale: :fr)
  end

  test "locales fall back to English" do
    assert_includes I18n.fallbacks[:de], :en
    # A key present only in English still resolves under another locale.
    I18n.backend.store_translations(:en, ea: { fallback_probe: "English only" })
    assert_equal "English only", I18n.t("ea.fallback_probe", locale: :fr)
  ensure
    I18n.reload!
  end

  test "change_language stores a valid language and rejects others" do
    post "/localization/change_language", params: { language: "german" }
    assert_equal({ "success" => true }, response.parsed_body)
    assert_equal "german", session[:language]

    post "/localization/change_language", params: { language: "klingon" }
    assert_equal false, response.parsed_body["success"]
  end

  test "booking page renders in the session language and injects its lang payload" do
    post "/localization/change_language", params: { language: "german" }
    get "/"
    assert_response :success
    assert_match "Vereinbaren Sie einen Termin mit", response.body
    assert_match "window.lang", response.body
  end

  test "language query param switches and persists to session" do
    get "/", params: { language: "french" }
    assert_response :success
    assert_equal "french", session[:language]
    assert_equal "fr", Localization.code_for("french")
  end

  test "Localization.translations returns the flat ea payload for a locale" do
    payload = Localization.translations("german")
    assert_equal "Vereinbaren Sie einen Termin mit", payload["page_title"]
  end
end
