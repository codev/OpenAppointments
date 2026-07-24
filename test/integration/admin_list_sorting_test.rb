require "test_helper"

# Admin list ordering: names alphabetical, customers by most recent interaction.
class AdminListSortingTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "providers, services and categories come back alphabetical" do
    login_admin
    provider_role = Role.find_by!(slug: Role::PROVIDER)
    User.create!(name: "Aaron Early", email: "aaron-p@example.org", role: provider_role)
    Service.create!(name: "AAA First Service", duration: 30)
    ServiceCategory.create!(name: "AAA First Category")

    post "/providers/search", params: { keyword: "" }
    names = response.parsed_body.map { |row| row["name"] }
    assert_equal names.sort, names

    post "/services/search", params: { keyword: "" }
    names = response.parsed_body.map { |row| row["name"] }
    assert_equal names.sort, names

    post "/service_categories/search", params: { keyword: "" }
    names = response.parsed_body.map { |row| row["name"] }
    assert_equal names.sort, names
  end

  test "customers order by last interaction, most recent first" do
    login_admin
    customer_role = Role.find_by!(slug: Role::CUSTOMER)
    quiet = User.create!(name: "Quiet Customer", email: "quiet@example.org", role: customer_role)
    active = User.create!(name: "Active Customer", email: "active@example.org", role: customer_role)

    # The quiet customer's profile was touched more recently, but the active one
    # has a newer appointment: the appointment wins.
    quiet.update_columns(updated_at: 1.day.ago)
    active.update_columns(updated_at: 10.days.ago)
    Appointment.create!(
      id_users_provider: users(:zane).id, id_users_customer: active.id,
      id_services: services(:haircut).id, start_datetime: Time.current + 1.day,
      end_datetime: Time.current + 1.day + 30.minutes, book_datetime: Time.current,
      notes: "", location: ""
    )

    post "/customers/search", params: { keyword: "" }
    names = response.parsed_body.map { |row| row["name"] }
    assert_operator names.index("Active Customer"), :<, names.index("Quiet Customer")

    # A newer message flips the order back.
    Message.create!(direction: "incoming", channel: "email", audience: "customer",
                    customer_id: quiet.id, from_address: "quiet@example.org", body: "Hello")
    post "/customers/search", params: { keyword: "" }
    names = response.parsed_body.map { |row| row["name"] }
    assert_operator names.index("Quiet Customer"), :<, names.index("Active Customer")
  end
end
