require "test_helper"

# Repeated failed logins are refused for a while, even with the right
# password, and the maintainer is told once per limit.
class LoginThrottleTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @null_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @null_cache }

  def attempt(username, password)
    post "/login/validate", params: { username: username, password: password }
    response.parsed_body["success"]
  end

  test "five failures on a username block it for the window and tell the maintainer once" do
    5.times { assert_equal false, attempt("administrator", "wrong") }
    assert_enqueued_emails 1
    assert_equal false, attempt("administrator", "administrator1")
    assert_enqueued_emails 1

    travel LoginThrottle::WINDOW + 1.minute do
      assert_equal true, attempt("administrator", "administrator1")
    end
  end

  test "twenty failures from one address block every username" do
    20.times { |i| attempt("user#{i}", "wrong") }
    assert_equal false, attempt("administrator", "administrator1")
    assert_enqueued_emails 1
  end

  test "a successful login clears the username's count" do
    4.times { attempt("administrator", "wrong") }
    assert_equal true, attempt("administrator", "administrator1")
    reset!
    4.times { attempt("administrator", "wrong") }
    assert_equal true, attempt("administrator", "administrator1")
  end

  test "the alert names the address and username" do
    mail = AlertMailer.login_attempts("203.0.113.9", "administrator")
    assert_equal "[OpenAppointments] Repeated failed logins", mail.subject
    assert_match "203.0.113.9", mail.body.to_s
    assert_match "administrator", mail.body.to_s
    assert_match "15 minutes", mail.body.to_s
  end
end
