require "test_helper"

class ResetDatabaseTest < ActiveSupport::TestCase
  test "reset removes business data and keeps admins and settings" do
    assert Appointment.any?
    assert User.customers.any?
    Setting.set("company_name", "Keep Me")

    ResetDatabase.run

    assert_equal 0, Appointment.count
    assert_equal 0, User.customers.count
    assert_equal 0, User.providers.count
    assert_equal 0, User.secretaries.count
    assert_equal 0, Service.count
    assert_equal 0, ServiceCategory.count
    assert User.admins.any?, "admins must survive a reset"
    assert_equal "Keep Me", Setting.get("company_name")
    assert Setting.get("book_advance_timeout").present?, "seed defaults restored"
  end
end
