require "test_helper"

class SmsAddressTest < ActiveSupport::TestCase
  test "sms addresses normalise to E.164" do
    assert_equal "+447971862965", Messaging::Template.e164("07971 862965")
    assert_equal "+447971862965", Messaging::Template.e164("07971862965")
    assert_equal "+447971862965", Messaging::Template.e164("+447971862965")
    assert_equal "+447971862965", Messaging::Template.e164("00447971862965")
    assert_nil Messaging::Template.e164("")
    assert_equal "+447971862965", Messaging::Template.e164("447971862965"), "country code without the plus"
    assert_equal "4479718", Messaging::Template.e164("4479718"), "too short to be international"

    user = users(:jx)
    user.update!(phone_number: "07971 862965", mobile_number: nil)
    assert_equal "+447971862965", Messaging::Template.sms_address(user)
  end
end
