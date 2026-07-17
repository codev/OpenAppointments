require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "EA security headers are present on responses" do
    get "/"
    assert_response :success
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    assert_equal "geolocation=(), microphone=(), camera=()", response.headers["Permissions-Policy"]
  end
end
