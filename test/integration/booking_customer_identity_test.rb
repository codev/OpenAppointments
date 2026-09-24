require "test_helper"

# A booking is the same customer only when the contact details and the name
# both match; people sharing an email or phone keep their own records.
class BookingCustomerIdentityTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  DATE = "2026-07-20".freeze # Monday; appointments(:upcoming) holds 10:00

  setup do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")
  end

  def register(customer, time: "11:00", provider: users(:zane))
    travel_to(Time.new(2026, 7, 10, 12, 0, 0)) do
      post "/booking/register", params: {
        form: "1", service_id: services(:haircut).id, provider_id: provider.id, date: DATE, time: time,
        appointment: { id_services: services(:haircut).id, id_users_provider: provider.id,
                       start_datetime: "#{DATE} #{time}:00" },
        customer: customer
      }
    end
  end

  def book(customer, **options)
    register(customer, **options)
    assert_response :redirect
    Appointment.order(:id).last.customer
  end

  # A second stylist, so a customer can be booked at a time Zane is busy.
  def riley
    provider = User.create!(name: "Riley", email: "riley@example.org", role: Role.find_by!(slug: Role::PROVIDER),
                            timezone: "Europe/London")
    provider.create_settings!(username: "riley", password: Passwords.hash("rileypass1"),
                              working_plan: user_settings(:zane).working_plan)
    ServiceProviderLink.create!(id_users: provider.id, id_services: services(:haircut).id)
    provider
  end

  test "a partner sharing an email under another name becomes a new customer" do
    customer = book({ name: "Partner Of JX", email: users(:jx).email })
    assert_not_equal users(:jx).id, customer.id
    assert_equal "Partner Of JX", customer.name
    assert_equal users(:jx).email, customer.email
    assert_equal "JX", users(:jx).reload.name
  end

  test "the same email and name in another case is the same customer and a new phone number replaces the old" do
    customer = nil
    assert_no_difference "User.customers.count" do
      customer = book({ name: " jx ", email: users(:jx).email.upcase, phone_number: "07700 900999" })
    end
    assert_equal users(:jx).id, customer.id
    assert_equal "07700 900999", customer.phone_number
    assert_equal "JX", customer.name
  end

  test "a shared phone number under another name without an email becomes a new customer" do
    Setting.set("require_email", "0")
    customer = book({ name: "Flatmate", email: "", phone_number: "07700 900321" })
    assert_not_equal users(:jx).id, customer.id
    assert_equal "JX", users(:jx).reload.name
  end

  test "fields left blank or not on the form keep the stored details" do
    users(:jx).update!(address: "1 High Street", city: "London", zip_code: "E1 1AA", custom_field_1: "they/them")
    customer = book({ name: "JX", email: users(:jx).email, phone_number: "", custom_field_1: "" })
    assert_equal users(:jx).id, customer.id
    assert_equal [ "1 High Street", "London", "E1 1AA", "+447700900321", "they/them" ],
                 [ customer.address, customer.city, customer.zip_code, customer.phone_number, customer.custom_field_1 ]
  end

  test "a partner is booked with another stylist at the same time as the customer they share an email with" do
    customer = book({ name: "Partner Of JX", email: users(:jx).email }, time: "10:00", provider: riley)
    assert_not_equal users(:jx).id, customer.id
  end

  test "a customer is refused a booking that partly overlaps one they already have" do
    assert_no_difference "Appointment.count" do
      register({ name: "JX", email: users(:jx).email }, time: "10:15", provider: riley)
    end
    assert_includes response.body, I18n.t("ea.customer_is_already_booked")
  end
end
