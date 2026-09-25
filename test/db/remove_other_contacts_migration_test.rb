require "test_helper"
require Rails.root.join("db/migrate/20260925120000_remove_other_contacts_from_users")

# Dropping the 2.2.0 contact columns must leave every row that points at a
# user in place: rebuilding the users table cascaded and deleted them.
class RemoveOtherContactsMigrationTest < ActiveSupport::TestCase
  test "dropping the columns keeps users' settings, appointments and links" do
    connection = ActiveRecord::Base.connection
    connection.add_column :users, :other_emails, :text
    connection.add_column :users, :other_phones, :text
    counts = -> { [ UserSetting.count, Appointment.count, ServiceProviderLink.count ] }
    before = counts.call
    assert before.all?(&:positive?)

    ActiveRecord::Migration.suppress_messages { RemoveOtherContactsFromUsers.new.up }

    assert_equal before, counts.call
    User.reset_column_information
    assert_not User.column_names.include?("other_emails")
  end
end
