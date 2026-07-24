require "test_helper"

class AuthFlowTest < ActionDispatch::IntegrationTest
  test "login validate success sets session and allows backend access" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_response :success
    assert_equal({ "success" => true }, response.parsed_body)

    get "/calendar"
    assert_response :success
  end

  test "login validate failure returns EA error shape" do
    post "/login/validate", params: { username: "administrator", password: "wrong" }
    assert_response :success
    body = response.parsed_body
    assert_equal false, body["success"]
    assert_match(/invalid credentials/i, body["message"])
  end

  test "backend requires session" do
    get "/calendar"
    assert_redirected_to "/login"
  end

  test "permission check forbids customer role" do
    customer = users(:jx)
    customer.create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }
    assert_equal({ "success" => true }, response.parsed_body)

    get "/calendar"
    assert_response :forbidden
  end

  test "logout clears the session" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/logout"
    assert_response :success
    get "/calendar"
    assert_redirected_to "/login"
  end

  test "recovery perform always succeeds and sends email only for real users" do
    assert_enqueued_emails 1 do
      post "/recovery/perform", params: { username: "janedoe", email: "zane@example.org" }
    end
    assert_equal({ "success" => true }, response.parsed_body)

    assert_no_enqueued_emails do
      post "/recovery/perform", params: { username: "nobody", email: "nobody@example.org" }
    end
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "full password reset flow" do
    post "/recovery/perform", params: { username: "janedoe", email: "zane@example.org" }
    token = user_settings(:zane).reload.password_reset_token
    assert token.present?

    plain_token = Accounts.generate_reset_token("janedoe", "zane@example.org")[:token]

    get "/recovery/reset", params: { token: plain_token }
    assert_response :success
    assert_match "password-reset-form", response.body

    post "/recovery/complete", params: { token: plain_token, password: "brandnew77", password_confirm: "brandnew77" }
    assert_equal({ "success" => true }, response.parsed_body)

    post "/login/validate", params: { username: "janedoe", password: "brandnew77" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "reset page rejects malformed and unknown tokens" do
    # EA's invalid_reset_token wording for malformed tokens.
    get "/recovery/reset", params: { token: "zzz" }
    assert_response :success
    assert_match(/reset link is invalid/, response.body)

    get "/recovery/reset", params: { token: "a" * 64 }
    assert_match(/invalid or has expired/, response.body)

    get "/recovery/reset"
    assert_redirected_to "/recovery"
  end

  test "mismatched reset passwords rejected" do
    plain_token = Accounts.generate_reset_token("janedoe", "zane@example.org")[:token]
    post "/recovery/complete", params: { token: plain_token, password: "brandnew77", password_confirm: "different77" }
    body = response.parsed_body
    assert_equal false, body["success"]
    assert_match(/do not match/, body["message"])
  end
end
