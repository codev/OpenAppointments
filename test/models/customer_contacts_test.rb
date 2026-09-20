require "test_helper"

# A customer can have other emails and phone numbers, one per line. They are
# found by any of them; phones compare in E.164 however they were typed.
class CustomerContactsTest < ActiveSupport::TestCase
  setup do
    @customer = User.create!(name: "Many Numbers", email: "Main@example.org", phone_number: "07700 900100",
                             other_emails: "second@example.org\nthird@example.org", other_phones: "+447700900101",
                             role: roles(:customer))
  end

  test "lists and lookups cover the primary and the others" do
    assert_equal %w[second@example.org third@example.org], @customer.other_email_list
    assert_equal %w[main@example.org second@example.org third@example.org], @customer.all_emails
    assert_equal %w[+447700900100 +447700900101], @customer.all_phones
    assert_equal @customer, User.customer_by_email("THIRD@example.org")
    assert_equal @customer, User.customer_by_email("main@example.org")
    assert_equal @customer, User.customer_by_phone("07700900101")
    assert_equal @customer, User.customer_by_phone("+44 7700 900100")
    assert_nil User.customer_by_email("nobody@example.org")
    assert_equal @customer, User.customer_by_contact(email: "nobody@example.org", phone: "07700 900101")
  end

  test "adding a contact keeps known ones out and fills a blank primary first" do
    @customer.add_contact(email: "Second@example.org", phone: "+447700900100")
    assert_not @customer.changed?
    @customer.add_contact(email: "new@example.org", phone: "07700 900102")
    assert_equal %w[second@example.org third@example.org new@example.org], @customer.other_email_list
    assert_equal %w[+447700900101 +447700900102], @customer.other_phone_list

    blank = User.new(name: "Blank", role: roles(:customer))
    blank.add_contact(email: "first@example.org", phone: "07700 900103")
    assert_equal [ "first@example.org", "07700 900103", [] ], [ blank.email, blank.phone_number, blank.other_email_list ]
  end
end
