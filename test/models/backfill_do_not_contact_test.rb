require "test_helper"

# Customers imported before the do_not_contact column carried the flag as a
# notes prefix; the backfill sets the column and strips the prefix.
class BackfillDoNotContactTest < ActiveSupport::TestCase
  MIGRATION = Rails.root.glob("db/migrate/*_backfill_do_not_contact_from_notes.rb").first
  PREFIX = "[DO NOT CONTACT - consent not granted]".freeze

  def migrate
    require MIGRATION
    ActiveRecord::Migration.suppress_messages { BackfillDoNotContactFromNotes.new.up }
  end

  test "a prefixed customer is flagged and the prefix is stripped" do
    flagged = users(:jx)
    flagged.update!(notes: "#{PREFIX} Prefers mornings", do_not_contact: false)
    plain = users(:zane)
    plain.update!(notes: "No prefix here", do_not_contact: false)

    migrate

    assert flagged.reload.do_not_contact
    assert_equal "Prefers mornings", flagged.notes
    assert_not plain.reload.do_not_contact
    assert_equal "No prefix here", plain.notes
  end

  test "a prefix with nothing after it leaves empty notes and running twice changes nothing" do
    users(:jx).update!(notes: PREFIX, do_not_contact: false)
    migrate
    assert_equal "", users(:jx).reload.notes
    assert users(:jx).do_not_contact
    migrate
    assert_equal "", users(:jx).reload.notes
  end
end
