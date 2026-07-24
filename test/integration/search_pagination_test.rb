require "test_helper"

# Backend list searches page with limit/offset and report the unpaged total in
# the X-Total-Count header, which drives the pagination bar.
class SearchPaginationTest < ActionDispatch::IntegrationTest
  setup do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "customers search reports the total and windows the results" do
    role = Role.find_by!(slug: "customer")
    5.times { |i| User.create!(name: "Page Tester #{i}", email: "pager#{i}@example.org", role: role) }

    post "/customers/search", params: { keyword: "Page Tester", limit: 2, offset: 0 }
    assert_response :success
    assert_equal "5", response.headers["X-Total-Count"]
    assert_equal 2, response.parsed_body.length

    post "/customers/search", params: { keyword: "Page Tester", limit: 2, offset: 4 }
    assert_equal 1, response.parsed_body.length
    assert_equal "5", response.headers["X-Total-Count"]
  end

  test "services search reports the total with no keyword" do
    post "/services/search", params: { keyword: "", limit: 1, offset: 0 }
    assert_response :success
    assert_equal Service.count.to_s, response.headers["X-Total-Count"]
    assert_equal 1, response.parsed_body.length
  end

  test "providers search reports the total through the shared user search" do
    post "/providers/search", params: { keyword: "", limit: 1, offset: 0 }
    assert_response :success
    assert_equal User.providers.count.to_s, response.headers["X-Total-Count"]
  end

  test "webhooks, categories and blocked periods report totals" do
    %w[webhooks service_categories blocked_periods].each do |resource|
      post "/#{resource}/search", params: { keyword: "", limit: 1, offset: 0 }
      assert_response :success
      assert response.headers["X-Total-Count"].present?, "missing header for #{resource}"
    end
  end
end
