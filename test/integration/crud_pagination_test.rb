require "test_helper"

# Server side paging of the CRUD lists (20 per page as the jQuery pages had).
class CrudPaginationTest < ActionDispatch::IntegrationTest
  setup do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    role = Role.find_by!(slug: Role::CUSTOMER)
    45.times { |i| User.create!(name: "Page Tester #{i.to_s.rjust(2, '0')}", email: "pt#{i}@example.org", role: role) }
  end

  test "the customer list pages with links inside the frame and keeps the keyword" do
    get "/customers"
    assert_select ".customer-row", count: 20
    assert_select "turbo-frame#customers ul.pagination li.page-item.active a", text: "1"
    assert_select "ul.pagination a[href='/customers?page=3']", text: "3"
    assert_select "ul.pagination li.page-item.previous.disabled a"

    get "/customers", params: { page: 3, keyword: "tester" }
    assert_select ".customer-row", count: 5
    assert_select "ul.pagination li.page-item.active a", text: "3"
    assert_select "ul.pagination a[href='/customers?page=2&keyword=tester']"
    assert_select "ul.pagination li.page-item.next.disabled a"

    get "/customers", params: { page: 99 }
    assert_select ".customer-row", count: 6
  end

  test "a selected record opens on its own page; short lists have no pager" do
    quiet = User.customers.order(:updated_at).first
    quiet.update_columns(updated_at: 1.year.ago)
    get "/customers", params: { selected: quiet.id }
    assert_select ".customer-row.selected[data-id=?]", quiet.id.to_s
    assert_select "ul.pagination li.page-item.active a", text: "3"

    get "/admins"
    assert_select "ul.pagination", count: 0
    get "/services"
    assert_select "ul.pagination", count: 0
  end

  test "no converted page leaks template text as visible markup" do
    %w[customers admins assistants providers services service_categories blocked_periods webhooks].each do |page|
      [ "/#{page}", "/#{page}/new" ].each do |path|
        get path
        assert_response :success, path
        assert_no_match(/&lt;\/?(li|ul|a|div|span)\b/, response.body, "markup leaked on #{path}")
      end
    end
  end

  test "the customer list counts unread messages in one query per page" do
    Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                    customer_id: users(:jx).id, body: "Hello", status: "received")
    queries = 0
    counter = ->(*) { queries += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get "/customers" }
    assert_operator queries, :<, 60
    assert_select ".customer-row[data-id=?] .unread-badge", users(:jx).id.to_s, text: "1"
  end
end
