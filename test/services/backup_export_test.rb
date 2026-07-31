require "test_helper"

class BackupExportTest < ActiveSupport::TestCase
  setup do
    BackupExport.dir_override = Rails.root.join("tmp", "backup-export-test-#{SecureRandom.hex(4)}")
  end

  teardown do
    FileUtils.rm_rf(BackupExport.dir_override)
    BackupExport.dir_override = nil
  end

  test "run writes a dated ods and zip pair and lists them newest first" do
    files = BackupExport.run(now: Time.new(2026, 7, 31, 14, 30, 5))
    assert_equal "2026-07-31-143005-OpenAppointments.ods", files[:ods]
    assert_equal "2026-07-31-143005-OpenAppointments.zip", files[:zip]

    sheets = Ods.parse(BackupExport.dir.join(files[:ods]).to_s)
    assert_includes sheets.keys, "Customers"

    entries = []
    Zip::File.open(BackupExport.dir.join(files[:zip])) { |zip| entries = zip.map(&:name) }
    assert_includes entries, "OpenAppointments.ods"

    list = BackupExport.list
    assert_equal 1, list.size
    assert_equal({ "ods" => files[:ods], "zip" => files[:zip] }, list.first[:files])
    assert_equal Time.new(2026, 7, 31, 14, 30, 5), list.first[:date]
  end

  test "the zip bundles only the original pictures, no derivatives" do
    PictureVariants.attach(services(:haircut), file_fixture("picture.png").to_s,
                           filename: "haircut.png", content_type: "image/png")
    files = BackupExport.run(now: Time.new(2026, 7, 31, 15, 0, 0))
    entries = []
    Zip::File.open(BackupExport.dir.join(files[:zip])) { |zip| entries = zip.map(&:name) }
    assert_includes entries, "haircut.png"
    assert(entries.none? { |name| name.start_with?("padded-", "zoomed-") },
           "backups must carry only the originals")
    assert_equal file_fixture("picture.png").binread,
                 Zip::File.open(BackupExport.dir.join(files[:zip])) { |zip| zip.read("haircut.png") }
  end

  test "prune keeps only the newest five pairs" do
    7.times { |i| BackupExport.run(now: Time.new(2026, 7, 1 + i, 12, 0, 0)) }
    list = BackupExport.list
    assert_equal 5, list.size
    assert_equal "2026-07-07-120000", list.first[:stamp]
    assert_equal "2026-07-03-120000", list.last[:stamp]
    assert_equal 10, Dir.children(BackupExport.dir).size
  end

  test "valid_name rejects anything off the pattern" do
    assert BackupExport.valid_name?("2026-07-31-143005-OpenAppointments.ods")
    assert BackupExport.valid_name?("2026-07-31-143005-OpenAppointments.zip")
    assert_not BackupExport.valid_name?("../../config/master.key")
    assert_not BackupExport.valid_name?("2026-07-31-143005-OpenAppointments.txt")
    assert_not BackupExport.valid_name?("evil-2026-07-31-143005-OpenAppointments.ods")
  end
end
