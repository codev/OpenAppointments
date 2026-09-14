require "test_helper"

class AppointmentReportTest < ActiveSupport::TestCase
  LABELS = ->(key) { key.tr("_", " ").capitalize }

  def sheet(**options)
    path = Rails.root.join("tmp", "appointment-report-#{SecureRandom.hex(4)}.ods")
    File.binwrite(path, AppointmentReport.generate(from: Date.new(2026, 7, 20), to: Date.new(2026, 7, 20),
                                                   labels: LABELS, **options))
    Ods.parse(path.to_s)["Appointments"]
  ensure
    FileUtils.rm_f(path)
  end

  test "ends with the displayed custom fields under their labels and the customer notes" do
    Setting.set("display_custom_field_1", "1")
    Setting.set("label_custom_field_1", "Pronouns")
    Setting.set("display_custom_field_3", "1")
    users(:jx).update!(custom_field_1: "they/them", custom_field_3: "Step free", notes: "No dye")

    header, row = sheet
    assert_equal [ "Pronouns", "Custom field #3", "Customer notes" ], header.last(3)
    assert_equal [ "they/them", "Step free", "No dye" ], row.last(3)
  end

  test "hidden custom fields are left out" do
    users(:jx).update!(custom_field_1: "they/them", notes: "No dye")

    header, row = sheet
    assert_equal "Customer notes", header.last
    assert_equal "Booked on", header[-2]
    assert_equal "No dye", row.last
    assert_not_includes row, "they/them"
  end
end
