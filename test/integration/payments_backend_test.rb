require "test_helper"
require_relative "api/v1/api_helper"

# Payment state in the backend: the Payment fields of the appointment dialog,
# the Unpaid marker on the calendar and the List, the API fields, the export
# and its import, and the appointments report.
class PaymentsBackendTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def edit_params(extra)
    appointment = appointments(:upcoming)
    { appointment: { id_services: appointment.id_services, id_users_provider: appointment.id_users_provider,
                     start_datetime: "20/07/2026 10:00 am", duration: 30, status: "Booked" }.merge(extra),
      customer: { id: appointment.id_users_customer } }
  end

  test "the dialog shows the Payment fields while payments are on or the appointment has a method" do
    login_admin
    get "/appointments/#{appointments(:upcoming).id}/edit"
    assert_select "#appointment-payment-method", 0
    assert_select "#appointment-paid", 0

    Setting.set("payments_enabled", "1")
    get "/appointments/#{appointments(:upcoming).id}/edit"
    assert_select "select#appointment-payment-method[name='appointment[payment_method]']" do
      assert_select "option[value=''][selected]", text: "No payment"
      assert_select "option[value=bank_transfer]", text: "Bank transfer"
      assert_select "option[value=stripe]", text: "Stripe"
    end
    assert_select "input#appointment-paid[type=checkbox][name='appointment[paid]']:not([checked])"

    Setting.set("payments_enabled", "0")
    appointments(:upcoming).update!(payment_method: "stripe", paid_at: Time.current)
    get "/appointments/#{appointments(:upcoming).id}/edit"
    assert_select "#appointment-payment-method option[value=stripe][selected]"
    assert_select "input#appointment-paid[checked]"
  end

  test "saving the dialog records the method and the Paid switch stamps or clears paid_at" do
    login_admin
    appointment = appointments(:upcoming)
    travel_to Time.new(2026, 7, 2, 9, 0, 0) do
      patch "/appointments/#{appointment.id}", params: edit_params(payment_method: "bank_transfer", paid: "1")
    end
    assert_response :success
    appointment.reload
    assert_equal "bank_transfer", appointment.payment_method
    assert_equal Time.new(2026, 7, 2, 9, 0, 0), appointment.paid_at

    travel_to Time.new(2026, 7, 3, 9, 0, 0) do
      patch "/appointments/#{appointment.id}", params: edit_params(payment_method: "bank_transfer", paid: "1")
    end
    assert_equal Time.new(2026, 7, 2, 9, 0, 0), appointment.reload.paid_at, "already paid keeps its time"

    patch "/appointments/#{appointment.id}", params: edit_params(payment_method: "paypal", paid: "0")
    appointment.reload
    assert_nil appointment.payment_method, "an unknown method clears it"
    assert_nil appointment.paid_at
  end

  test "an unpaid tracked payment marks the List entry and the calendar row, pay in person does not" do
    login_admin
    appointment = appointments(:upcoming)
    appointment.update!(payment_method: "bank_transfer")
    get "/appointments", params: { date: "2026-07-20" }
    assert_select ".day-entry-appointment .day-entry-title", text: /JX - Trim Cut \(Unpaid\)/

    post "/calendar/get_calendar_appointments",
         params: { filter_type: "all", record_id: "all", start_date: "2026-07-20", end_date: "2026-07-20" }
    row = response.parsed_body["appointments"].find { |r| r["id"] == appointment.id }
    assert_equal "bank_transfer", row["payment_method"]
    assert_equal "Bank transfer", row["payment_method_label"]
    assert_equal "unpaid", row["payment_status"]
    assert_equal true, row["payment_due"]
    assert_nil row["paid_at"]

    appointment.update!(payment_method: "in_person")
    get "/appointments", params: { date: "2026-07-20" }
    assert_select ".day-entry-appointment .day-entry-title", text: "JX - Trim Cut"

    appointment.update!(payment_method: "stripe", paid_at: Time.new(2026, 7, 2, 9, 0, 0))
    get "/appointments", params: { date: "2026-07-20" }
    assert_select ".day-entry-appointment .day-entry-title", text: "JX - Trim Cut"
    post "/calendar/get_calendar_appointments",
         params: { filter_type: "all", record_id: "all", start_date: "2026-07-20", end_date: "2026-07-20" }
    row = response.parsed_body["appointments"].find { |r| r["id"] == appointment.id }
    assert_equal "paid", row["payment_status"]
    assert_equal false, row["payment_due"]
    assert_equal "2026-07-02 09:00:00", row["paid_at"]
  end

  test "the export carries the payment columns and the import reads them back" do
    appointment = appointments(:upcoming)
    appointment.update!(payment_method: "stripe", payment_reference: "cs_1", paid_at: Time.new(2026, 7, 2, 9, 0, 0))
    sheets = DataExport.sheets
    header = sheets["Appointments"].first
    columns = %w[payment_method payment_reference paid_at].map { |name| header.index(name) }
    assert_not_includes columns, nil
    row = sheets["Appointments"].find { |r| r[header.index("booking_hash")] == appointment.booking_hash }
    assert_equal [ "stripe", "cs_1", "2026-07-02 09:00:00" ], row.values_at(*columns)

    path = Rails.root.join("tmp", "payments-export-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, Ods.generate(sheets))
    extracted = OdsExtract.new(path.to_s, today: Date.new(2026, 7, 20)).call[:appointments]
    imported = extracted.find { |r| r[:start].to_i == appointment.start_datetime.to_i }
    assert_equal "stripe", imported[:payment_method]
    assert_equal "cs_1", imported[:payment_reference]
    assert_equal Time.new(2026, 7, 2, 9, 0, 0), imported[:paid_at]
  end

  test "the appointments report lists the payment method and status" do
    appointments(:upcoming).update!(payment_method: "bank_transfer")
    rows = AppointmentReport.rows(Date.new(2026, 7, 20), Date.new(2026, 7, 20), nil, [])
    header = AppointmentReport::COLUMNS
    row = rows.first
    assert_equal "Bank transfer", row[header.index("payment_method")]
    assert_equal "Unpaid", row[header.index("payment_status")]
  end
end

module Api
  module V1
    class PaymentsApiTest < ApiTestCase
      test "appointments expose and accept the payment method and paid time" do
        appointments(:upcoming).update!(payment_method: "stripe", paid_at: Time.new(2026, 7, 2, 9, 0, 0))
        api_get "/api/v1/appointments/#{appointments(:upcoming).id}"
        assert_equal "stripe", json["paymentMethod"]
        assert_equal "2026-07-02 09:00:00", json["paidAt"]

        api_put "/api/v1/appointments/#{appointments(:upcoming).id}", { paymentMethod: "bank_transfer", paidAt: nil }
        assert_response :success
        appointment = appointments(:upcoming).reload
        assert_equal "bank_transfer", appointment.payment_method
        assert_nil appointment.paid_at
      end
    end
  end
end
