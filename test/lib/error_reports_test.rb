require "test_helper"

# Crash report recipients come from the EXCEPTION_RECIPIENTS environment
# variable so the address is set per instance, never in the code.
class ErrorReportsTest < ActiveSupport::TestCase
  test "recipients are the comma separated addresses in the environment" do
    with_env("EXCEPTION_RECIPIENTS" => "ops@example.org, second@example.org") do
      assert_equal %w[ops@example.org second@example.org], ErrorReports.recipients
    end
  end

  test "no variable means no recipients" do
    with_env("EXCEPTION_RECIPIENTS" => nil) { assert_equal [], ErrorReports.recipients }
    with_env("EXCEPTION_RECIPIENTS" => " ") { assert_equal [], ErrorReports.recipients }
  end

  def with_env(pairs)
    saved = pairs.keys.to_h { |key| [ key, ENV[key] ] }
    pairs.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
