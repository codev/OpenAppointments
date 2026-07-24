require "test_helper"

# A fresh install's admin (default password) is forced to the account page
# until they set a new password.
class FirstLoginTest < ActionDispatch::IntegrationTest
  setup do
    users(:admin).settings.update!(require_password_change: true)
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "backend pages redirect to the account page until the password changes" do
    get "/calendar"
    assert_redirected_to "/account"

    get "/customers"
    assert_redirected_to "/account"
  end

  test "the account page renders with the banner" do
    get "/account"
    assert_response :success
    assert_select "#password-change-banner", text: /#{I18n.t('ea.first_login_update_details')}/
  end

  test "saving a new password clears the flag and unlocks the backend" do
    post "/account/save", params: {
      account: {
        name: users(:admin).name, email: users(:admin).email, timezone: "UTC",
        settings: { username: "administrator", password: "brand-new-password1" }
      }
    }
    assert_response :success
    assert_not users(:admin).settings.reload.require_password_change

    get "/calendar"
    assert_response :success

    get "/account"
    assert_select "#password-change-banner", false
  end

  test "saving without a password keeps the lock" do
    post "/account/save", params: {
      account: { name: users(:admin).name, email: users(:admin).email, timezone: "UTC",
                 settings: { username: "administrator" } }
    }
    assert_response :success
    assert users(:admin).settings.reload.require_password_change

    get "/calendar"
    assert_redirected_to "/account"
  end

  test "the banner string exists in every locale" do
    I18n.available_locales.each do |locale|
      assert I18n.t("ea.first_login_update_details", locale: locale, fallback: false, default: nil).present?,
             "missing ea.first_login_update_details in #{locale}"
    end
  end
end
