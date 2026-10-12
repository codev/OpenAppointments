require "test_helper"

# Every locale carries the 3.0.0 strings: the login page reads Staff Login with
# its welcome line, the header names the Appointments page List, and the
# import counts name do-not-contact customers.
class LocaleStrings300Test < ActionDispatch::IntegrationTest
  KEYS = %w[backend_section you_need_to_login do_not_contact list].freeze

  test "the 3.0.0 strings exist in every locale" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
    end
    assert_equal "Staff Login", I18n.t("ea.backend_section", locale: :en)
    assert_equal "Welcome! You will need to login in order to manage appointments and messages.",
                 I18n.t("ea.you_need_to_login", locale: :en)
    assert_equal "Do not contact", I18n.t("ea.do_not_contact", locale: :en)
  end

  test "the login page says Staff Login with the welcome line" do
    get "/login"
    assert_select "h2, h3, h4, h5", text: "Staff Login"
    assert_includes response.body, "manage appointments and messages"
  end

  test "the header names the Appointments page List" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/calendar"
    assert_select "#header a.nav-link[href='/appointments']", text: /\A\s*List\s*\z/
  end
end
