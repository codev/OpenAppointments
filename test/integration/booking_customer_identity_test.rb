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

  def register(customer, time: "11:00")
    travel_to(Time.new(2026, 7, 10, 12, 0, 0)) do
      post "/booking/register", params: {
        form: "1", service_id: services(:haircut).id, provider_id: users(:zane).id, date: DATE, time: time,
        appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id,
                       start_datetime: "#{DATE} #{time}:00" },
        customer: customer
      }
    end
    assert_response :redirect
    Appointment.order(:id).last.customer
  end

  test "a partner sharing an email under another name becomes a new customer" do
    customer = register({ name: "Partner Of JX", email: users(:jx).email })
    assert_not_equal users(:jx).id, customer.id
    assert_equal "Partner Of JX", customer.name
    assert_equal users(:jx).email, customer.email
    assert_equal "JX", users(:jx).reload.name
  end

  test "the same email and name in another case is the same customer and a new phone number replaces the old" do
    customer = nil
    assert_no_difference "User.customers.count" do
      customer = register({ name: " jx ", email: users(:jx).email.upcase, phone_number: "07700 900999" })
    end
    assert_equal users(:jx).id, customer.id
    assert_equal "07700 900999", customer.phone_number
    assert_equal "JX", customer.name
  end

  test "a shared phone number under another name without an email becomes a new customer" do
    Setting.set("require_email", "0")
    customer = register({ name: "Flatmate", email: "", phone_number: "07700 900321" })
    assert_not_equal users(:jx).id, customer.id
    assert_equal "JX", users(:jx).reload.name
  end

  test "fields left blank or not on the form keep the stored details" do
    users(:jx).update!(address: "1 High Street", city: "London", zip_code: "E1 1AA", custom_field_1: "they/them")
    customer = register({ name: "JX", email: users(:jx).email, phone_number: "", custom_field_1: "" })
    assert_equal users(:jx).id, customer.id
    assert_equal [ "1 High Street", "London", "E1 1AA", "+447700900321", "they/them" ],
                 [ customer.address, customer.city, customer.zip_code, customer.phone_number, customer.custom_field_1 ]
  end
end
