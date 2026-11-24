require "test_helper"

# Rails autoloads the app's own constants, not the standard library, and nothing
# in the production bundle loads net/http at boot. Each file that calls Net::HTTP
# must require it itself. The test environment hides the gap because the test
# gems load net/http, so this checks the source instead.
class NetHttpRequiresTest < ActiveSupport::TestCase
  test "every file that uses Net::HTTP requires net/http" do
    users = Dir.glob(Rails.root.join("app/**/*.rb")).select { |path| File.read(path).include?("Net::HTTP") }
    assert users.any?, "expected Net::HTTP users under app/"

    missing = users.reject { |path| File.read(path).match?(%r{^require "net/http"$}) }
    assert_empty missing.map { |path| path.delete_prefix("#{Rails.root}/") }
  end
end
