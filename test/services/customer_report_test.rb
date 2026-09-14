require "test_helper"

class CustomerReportTest < ActiveSupport::TestCase
  NOW = Time.new(2026, 9, 14, 12, 0, 0)

  setup do
    @kai = User.create!(name: "Kai", email: "kai@example.org", role: roles(:provider))
    @solo = User.create!(name: "Solo", email: "solo@example.org", role: roles(:customer))
    @idle = User.create!(name: "Idle", email: "idle@example.org", role: roles(:customer))
  end

  def book(customer, provider, service, start, status: "Booked")
    Appointment.create!(start_datetime: start, end_datetime: start + 30.minutes, provider: provider,
                        customer: customer, service: service, status: status)
  end

  def sheet
    path = Rails.root.join("tmp", "customer-report-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, CustomerReport.generate(now: NOW))
    Ods.parse(path.to_s)["Customers"]
  ensure
    FileUtils.rm_f(path)
  end

  def row_for(rows, name) = rows.find { |row| row.first == name }

  test "header: details, displayed custom fields, notes, then the last-year counts" do
    Setting.set("display_custom_field_2", "1")
    Setting.set("label_custom_field_2", "Access needs")

    assert_equal %w[name email phone_number address city zip_code] +
                 [ "Access needs", "notes", "appointments_in_last_year", "providers", "services",
                   "Cancelled", "Late Cancel", "Rescheduled" ],
                 sheet.first
  end

  test "counts and lists cover the last year and skip cancelled, late cancelled and rescheduled" do
    jx = users(:jx)
    jx.update!(notes: "Regular")
    # The fixture appointment: 2026-07-20 with Zane, Trim Cut, Booked.
    book(jx, users(:zane), services(:haircut), NOW - 2.months, status: "Confirmed")
    book(jx, @kai, services(:group_session), NOW - 3.months)
    book(jx, @kai, services(:haircut), NOW - 13.months)
    book(jx, @kai, services(:haircut), NOW + 1.day)
    book(jx, users(:zane), services(:haircut), NOW - 1.month, status: "Cancelled")
    book(jx, users(:zane), services(:haircut), NOW - 1.week, status: "Late Cancel")
    book(jx, users(:zane), services(:haircut), NOW - 2.weeks, status: "Rescheduled")
    book(jx, users(:zane), services(:haircut), NOW - 14.months, status: "Cancelled")

    row = row_for(sheet, "JX")
    assert_equal [ "JX", "j@example.org", "+447700900321", "", "", "", "Regular" ], row.first(7)
    assert_equal [ "3", "Zane (2), Kai (1)", "Trim Cut (2), Group Session (1)", "1", "1", "1" ], row.last(6)
  end

  test "a single provider or service is shown as its name alone" do
    book(@solo, users(:zane), services(:haircut), NOW - 1.day)
    book(@solo, users(:zane), services(:haircut), NOW - 2.days)

    assert_equal [ "2", "Zane", "Trim Cut", "0", "0", "0" ], row_for(sheet, "Solo").last(6)
  end

  test "a customer with no appointments has zero counts and empty lists" do
    assert_equal [ "0", "", "", "0", "0", "0" ], row_for(sheet, "Idle").last(6)
  end

  test "the status columns follow the configured status names" do
    appointment_statuses(:late_cancel).update!(name: "Too Late")
    assert_equal [ "Cancelled", "Too Late", "Rescheduled" ], sheet.first.last(3)
  end

  test "customers are listed by name and staff are not customers" do
    names = sheet.drop(1).map(&:first)
    assert_equal names.sort, names
    assert_not_includes names, "Zane"
    assert_includes names, "Idle"
  end
end
