require "test_helper"

# Automated scanners hit the booking page with headers no browser sends. They
# get a terse refusal, not a crash report.
class ScannerRequestsTest < ActionDispatch::IntegrationTest
  test "a JSON request for the booking page is not acceptable" do
    get "/", headers: { "Accept" => "application/json", "Content-Type" => "application/json" }
    assert_response :not_acceptable
  end

  test "a JSON request for a reschedule link is not acceptable" do
    get "/booking/reschedule/nothing", headers: { "Accept" => "application/json" }
    assert_response :not_acceptable
  end

  test "a wildcard accept header still gets the booking page" do
    get "/", headers: { "Accept" => "*/*" }
    assert_response :success
  end

  test "a Client-IP header beside X-Forwarded-For gets the normal not found answer" do
    get "/wp-json/batch/v1", headers: { "Client-IP" => "127.0.0.1", "X-Forwarded-For" => "203.0.113.9" }
    assert_response :not_found
  end
end
