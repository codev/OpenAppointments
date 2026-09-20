require "application_system_test_case"

class ImportPageSystemTest < ApplicationSystemTestCase
  setup do
    TenToEightImportJob.status_store = ActiveSupport::Cache::MemoryStore.new
    BackupExportJob.status_store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    TenToEightImportJob.status_store = nil
    BackupExportJob.status_store = nil
  end

  test "the export button shows and analyze reports the dry run" do
    login_as_admin
    visit "/data"
    assert_selector "#export-data", visible: :visible, wait: 5
    assert_no_selector "turbo-frame#backups[src]"

    select "Sign In App / 10to8 CSV", from: "import-type"
    attach_file "import-file", Rails.root.join("test/fixtures/files/ten_to_eight_export.csv")
    find("#analyze-import").click
    assert_selector "#import-results", text: /customers: 3/, wait: 10
    assert_selector "#export-data", visible: :visible
  end
end
