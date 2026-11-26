require "test_helper"
require Rails.root.join("db/migrate/20261125223000_wrap_plain_service_descriptions")

# Descriptions written before the editor are plain text with line breaks; the
# migration turns them into paragraphs so the editor and the booking page show
# them as before. Descriptions already holding markup are left alone.
class WrapPlainServiceDescriptionsMigrationTest < ActiveSupport::TestCase
  test "plain descriptions become paragraphs, markup and blanks are untouched" do
    services(:haircut).update_columns(description: "Dry cuts only.\nBring a photo.\n\nNo colour.")
    services(:group_session).update_columns(description: "<p>Already <em>rich</em></p>")
    blank = Service.create!(name: "Blank", duration: 30, description: "")

    ActiveRecord::Migration.suppress_messages { WrapPlainServiceDescriptions.new.up }

    assert_equal "<p>Dry cuts only.\n<br />Bring a photo.</p>\n\n<p>No colour.</p>", services(:haircut).reload.description
    assert_equal "<p>Already <em>rich</em></p>", services(:group_session).reload.description
    assert_equal "", blank.reload.description
  end
end
