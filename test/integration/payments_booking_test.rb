require "test_helper"

# Payments in the booking flow: the accepted methods on the service form, the
# payment text or chooser on the confirmation step, the method recorded on the
# appointment and the instructions on the page confirming the booking.
class PaymentsBookingTest < ActionDispatch::IntegrationTest
  DATE = "2026-07-20".freeze # Monday, see availability engine tests

  setup do
    @state = { service_id: services(:haircut).id, provider_id: users(:zane).id, date: DATE, time: "11:00" }
    @customer = { name: "Paying Booker", email: "pay@example.org" }
    Setting.set("payments_enabled", "1")
    Setting.set("payments_in_person_instructions", "Cash or card at the salon")
  end

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def enable_bank_transfer
    Setting.set("payments_bank_transfer_enabled", "1")
    Setting.set("payments_bank_transfer_instructions", "Sort code 12-34-56\nAccount 12345678")
  end

  def confirm(extra = {})
    post "/booking/confirm", params: { form: "1", **@state, customer: @customer }.deep_merge(extra)
  end

  def register(extra = {})
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/booking/register", params: {
        form: "1", **@state,
        appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id, start_datetime: "#{DATE} 11:00:00" },
        customer: @customer
      }.deep_merge(extra)
    end
  end

  test "the service form ticks the accepted methods and marks inactive ones" do
    login_admin
    get "/services/#{services(:haircut).id}/edit"
    assert_select "#service-payment-methods input[type=checkbox][name='service[payment_method_keys][]'][value=in_person]"
    assert_select "#service-payment-methods input[type=checkbox][value=bank_transfer]"
    assert_select "#service-payment-methods input[type=checkbox][value=stripe]"
    assert_select "#service-payment-methods label[for=payment-method-stripe]", text: /Stripe.*inactive/m
    assert_select "#service-payment-methods label[for=payment-method-in_person]", text: /Pay in person\s*\z/

    patch "/services/#{services(:haircut).id}", params: { service: { name: "Trim Cut", payment_method_keys: [ "", "bank_transfer", "stripe" ] } }
    assert_equal %w[bank_transfer stripe], services(:haircut).reload.payment_method_keys

    get "/services/#{services(:haircut).id}/edit"
    assert_select "#service-payment-methods input[value=bank_transfer][checked]"
    assert_select "#service-payment-methods input[value=in_person][checked]", 0

    patch "/services/#{services(:haircut).id}", params: { service: { name: "Trim Cut", payment_method_keys: [ "" ] } }
    assert_equal [], services(:haircut).reload.payment_method_keys
  end

  test "the confirmation step shows the single method as text with its instructions" do
    confirm
    assert_response :success
    assert_select "#wizard-frame-5 #payment-details" do
      assert_select "input[type=hidden][name=payment_method][value=in_person]"
      assert_select "strong", text: "Pay in person"
      assert_select "p", text: "Cash or card at the salon"
      assert_select "input[type=radio]", 0
    end
    assert_select "#book-appointment-submit", text: /Confirm\z/
  end

  test "the confirmation step offers a chooser when the service accepts several methods" do
    enable_bank_transfer
    services(:haircut).update!(payment_method_keys: %w[in_person bank_transfer stripe])
    confirm
    assert_select "#payment-details" do
      assert_select "legend", text: "How would you like to pay?"
      assert_select "input[type=radio][name=payment_method][value=in_person][checked]"
      assert_select "input[type=radio][name=payment_method][value=bank_transfer]:not([checked])"
      assert_select "input[type=radio][value=stripe]", 0, "an inactive method is not offered"
      assert_select "label[for=payment-method-bank_transfer]", text: /Bank transfer/
      assert_select "#payment-method-bank_transfer-instructions", text: /Sort code 12-34-56/
    end

    confirm(payment_method: "bank_transfer")
    assert_select "input[type=radio][value=bank_transfer][checked]"
  end

  test "the confirmation step says nothing about payment when payments are off or on a reschedule" do
    Setting.set("payments_enabled", "0")
    confirm
    assert_select "#payment-details", 0

    Setting.set("payments_enabled", "1")
    confirm(manage_mode: "1", appointment_hash: appointments(:upcoming).booking_hash, time: "11:00")
    assert_select "#wizard-frame-5"
    assert_select "#payment-details", 0
  end

  test "register records the chosen method and refuses one the service does not offer" do
    enable_bank_transfer
    services(:haircut).update!(payment_method_keys: %w[in_person bank_transfer])

    register(payment_method: "bank_transfer")
    appointment = Appointment.order(:id).last
    assert_redirected_to "/booking_confirmation/of/#{appointment.booking_hash}"
    assert_equal "bank_transfer", appointment.payment_method
    assert_equal "unpaid", appointment.payment_status

    assert_no_difference "Appointment.count" do
      register(payment_method: "stripe", appointment: { start_datetime: "#{DATE} 09:00:00" }, time: "09:00")
    end
    assert_select "#form-message", text: I18n.t("ea.payments_method_not_offered")
  end

  test "register takes the only method without it being posted, and none when payments are off" do
    register
    assert_equal "in_person", Appointment.order(:id).last.payment_method

    Setting.set("payments_enabled", "0")
    register(appointment: { start_datetime: "#{DATE} 09:00:00" }, time: "09:00")
    assert_nil Appointment.order(:id).last.payment_method
  end

  test "a reschedule carries the original payment over" do
    original = appointments(:upcoming)
    original.update!(payment_method: "stripe", payment_reference: "cs_1", paid_at: Time.new(2026, 7, 1, 12, 0, 0))
    register(manage_mode: "1", appointment_hash: original.booking_hash, appointment: { id: original.id },
             customer: { name: users(:jx).name, email: users(:jx).email })
    replacement = original.reload.rescheduled_to
    assert_equal "stripe", replacement.payment_method
    assert_equal "cs_1", replacement.payment_reference
    assert_equal original.paid_at, replacement.paid_at
  end

  test "the page confirming the booking shows the method and its instructions" do
    appointment = appointments(:upcoming)
    get "/booking_confirmation/of/#{appointment.booking_hash}"
    assert_select "#payment-details", 0

    appointment.update!(payment_method: "in_person")
    get "/booking_confirmation/of/#{appointment.booking_hash}"
    assert_select "#payment-details" do
      assert_select "strong", text: "Pay in person"
      assert_select "p", text: "Cash or card at the salon"
    end
  end
end
