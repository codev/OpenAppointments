require "test_helper"
require Rails.root.join("db/migrate/20260926090000_store_phones_as_e164")

# Existing phones are rewritten in place (no table rebuild), so rows that
# point at users stay, and the lookup indexes are added.
class StorePhonesAsE164MigrationTest < ActiveSupport::TestCase
  test "existing phones become E.164 and child rows are kept" do
    connection = ActiveRecord::Base.connection
    migration = StorePhonesAsE164.new
    ActiveRecord::Migration.suppress_messages { migration.down }
    users(:jx).update_columns(phone_number: "07700 900.123", mobile_number: "(07700) 900124\n")
    users(:zane).update_columns(phone_number: "", mobile_number: "447700900125")
    entry = WaitlistEntry.create!(service: services(:haircut), name: "Wait", email: "w@example.org")
    entry.update_columns(phone: "07700 900126")
    counts = -> { [ UserSetting.count, Appointment.count, ServiceProviderLink.count, User.count ] }
    before = counts.call

    ActiveRecord::Migration.suppress_messages { migration.up }

    assert_equal before, counts.call
    assert_equal [ "+447700900123", "+447700900124" ], [ users(:jx).reload.phone_number, users(:jx).mobile_number ]
    assert_equal [ nil, "+447700900125" ], [ users(:zane).reload.phone_number, users(:zane).mobile_number ]
    assert_equal "+447700900126", entry.reload.phone
    assert connection.index_exists?(:users, :phone_number)
    assert connection.index_exists?(:users, :mobile_number)
  end
end
