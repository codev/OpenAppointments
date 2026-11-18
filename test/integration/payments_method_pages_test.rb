require "test_helper"
require "webmock/minitest"

# One settings page per payment method: Active and Default switches, the
# customer instructions for the text methods, keys and currency for Stripe with
# a Test credentials button that checks the form as it stands.
class PaymentsMethodPagesTest < ActionDispatch::IntegrationTest
  PAGES = %w[payments_in_person_settings payments_bank_transfer_settings payments_stripe_settings].freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  test "admin can view every method page, a provider cannot" do
    login_admin
    PAGES.each do |page|
      get "/#{page}"
      assert_response :success, "expected 200 for admin on /#{page}"
      assert_select "#payments-nav a[href='/payments_methods'].fw-bold", 1, "Methods is marked as the parent on /#{page}"
      assert_select "a[href='/payments_methods']", text: /Back/
    end
    reset!
    login_provider
    PAGES.each do |page|
      get "/#{page}"
      assert_response :forbidden, "expected 403 for provider on /#{page}"
    end
  end

  test "a text method page saves its switch, instructions and the default" do
    login_admin
    get "/payments_bank_transfer_settings"
    assert_select "input#bank_transfer-enabled[name='settings[payments_bank_transfer_enabled]']"
    assert_select "input#bank_transfer-default[name='settings[payments_bank_transfer_default]']"
    assert_select "textarea#payments-bank-transfer-instructions[name='settings[payments_bank_transfer_instructions]']"
    assert_select "#bank_transfer-test", 0, "text methods have nothing to test"

    post "/payments_bank_transfer_settings/save",
         params: { settings: { payments_bank_transfer_enabled: "1", payments_bank_transfer_default: "1",
                               payments_bank_transfer_instructions: "Sort code 12-34-56\nAccount 12345678",
                               payments_stripe_secret_key: "sk_smuggled" } }
    assert_redirected_to "/payments_bank_transfer_settings"
    assert_equal "1", Setting.get("payments_bank_transfer_enabled")
    assert_equal "bank_transfer", Setting.get("payments_default_method")
    assert_equal "Sort code 12-34-56\nAccount 12345678", Setting.get("payments_bank_transfer_instructions")
    assert_nil Setting.get("payments_stripe_secret_key"), "another method's setting is not saved from this page"

    get "/payments_bank_transfer_settings"
    assert_select "input#bank_transfer-default[checked]"
    get "/payments_in_person_settings"
    assert_select "input#in_person-default[checked]", 0

    post "/payments_in_person_settings/save", params: { settings: { payments_in_person_default: "0" } }
    assert_equal "bank_transfer", Setting.get("payments_default_method"), "off elsewhere leaves the default alone"
    post "/payments_bank_transfer_settings/save", params: { settings: { payments_bank_transfer_default: "0" } }
    assert_equal "", Setting.get("payments_default_method"), "off on its own page clears it"
  end

  test "the Stripe page has the keys, the currency and only the credentials test" do
    Setting.set("payments_stripe_secret_key", "sk_stored")
    login_admin
    get "/payments_stripe_settings"
    assert_select "input#payments-stripe-secret-key[type=password][name='settings[payments_stripe_secret_key]']" do |inputs|
      assert_nil inputs.first["value"], "the secret is never written into the page"
    end
    assert_select "input#payments-stripe-webhook-secret[type=password]"
    assert_select "input#payments-stripe-currency[value=GBP]"
    assert_select "#stripe-test[data-url='/payments_stripe_settings'] button#stripe-test-credentials[data-no-change]",
                  text: I18n.t("ea.messages_test_credentials")
    assert_select "#stripe-test .send-test", 0
    assert_select "#stripe-test .test-address", 0
    assert_select "script[src*='pages/messages_provider_settings']"

    post "/payments_stripe_settings/save",
         params: { settings: { payments_stripe_enabled: "1", payments_stripe_secret_key: "", payments_stripe_currency: " eur " } }
    assert_equal "1", Setting.get("payments_stripe_enabled")
    assert_equal "sk_stored", Setting.get("payments_stripe_secret_key"), "a blank secret keeps the stored one"
    assert_equal "EUR", Setting.get("payments_stripe_currency")

    post "/payments_stripe_settings/save", params: { settings: { payments_stripe_currency: "pounds" } }
    assert_redirected_to "/payments_stripe_settings"
    assert_equal I18n.t("ea.payments_invalid_currency"), flash[:alert]
    assert_equal "EUR", Setting.get("payments_stripe_currency")
  end

  test "Stripe credentials are checked with the posted key and a blank key uses the stored one" do
    login_admin
    Setting.set("payments_stripe_secret_key", "sk_stored")
    stub_request(:get, "https://api.stripe.com/v1/balance")
      .with(headers: { "Authorization" => "Bearer sk_stored" }).to_return(status: 200, body: '{"object":"balance"}')
    post "/payments_stripe_settings/test_credentials", params: { settings: { payments_stripe_secret_key: "" } }
    assert_equal true, response.parsed_body["success"]
    assert_equal I18n.t("ea.messages_test_credentials_ok"), response.parsed_body["message"]

    stub_request(:get, "https://api.stripe.com/v1/balance")
      .with(headers: { "Authorization" => "Bearer sk_bad" })
      .to_return(status: 401, body: { error: { message: "Invalid API Key provided" } }.to_json)
    post "/payments_stripe_settings/test_credentials", params: { settings: { payments_stripe_secret_key: "sk_bad" } }
    assert_equal false, response.parsed_body["success"]
    assert_match(/Stripe 401/, response.parsed_body["message"])
    assert_match(/Invalid API Key/, response.parsed_body["message"])
  end
end
