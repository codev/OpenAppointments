require "test_helper"

class AccountsTest < ActiveSupport::TestCase
  test "check_login returns EA session data on success" do
    data = Accounts.check_login("administrator", "administrator1")
    assert_equal users(:admin).id, data[:user_id]
    assert_equal "john@example.org", data[:user_email]
    assert_equal "administrator", data[:username]
    assert_equal "admin", data[:role_slug]
    assert_equal "UTC", data[:timezone]
  end

  test "check_login nil on wrong password or unknown user" do
    assert_nil Accounts.check_login("administrator", "wrong")
    assert_nil Accounts.check_login("nobody", "whatever")
  end

  test "check_login upgrades legacy hash to bcrypt" do
    settings = user_settings(:jane)
    salt = "f" * 64
    settings.update!(salt: salt, password: Passwords.legacy_hash(salt, "legacypass"))

    data = Accounts.check_login("janedoe", "legacypass")
    assert_equal users(:jane).id, data[:user_id]
    assert Passwords.bcrypt?(settings.reload.password)
    assert Passwords.verify(nil, "legacypass", settings.password)
  end

  test "reset token round trip" do
    result = Accounts.generate_reset_token("janedoe", "jane@example.org")
    assert_match(/\A[a-f0-9]{64}\z/, result[:token])
    assert_equal "jane@example.org", result[:email]

    settings = Accounts.validate_reset_token(result[:token])
    assert_equal users(:jane).id, settings.id_users

    assert Accounts.reset_password_with_token(result[:token], "newpass77")
    assert Passwords.verify(nil, "newpass77", settings.reload.password)
    assert_nil settings.password_reset_token
    assert_nil Accounts.validate_reset_token(result[:token])
  end

  test "generate_reset_token raises for unknown user" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Accounts.generate_reset_token("nobody", "nobody@example.org")
    end
  end

  test "expired token is rejected" do
    result = Accounts.generate_reset_token("janedoe", "jane@example.org")
    user_settings(:jane).update!(password_reset_expires: Time.now - 1)
    assert_nil Accounts.validate_reset_token(result[:token])
    assert_raises(ArgumentError) { Accounts.reset_password_with_token(result[:token], "newpass77") }
  end
end
