require "test_helper"

# The payment method registry: which methods exist, which are enabled, which is
# the default and which a service offers.
class PaymentsTest < ActiveSupport::TestCase
  test "three methods are registered, pay in person first" do
    assert_equal %w[in_person bank_transfer stripe], Payments.all.map(&:key)
    assert_equal Payments::Stripe, Payments.find("stripe")
    assert Payments::Stripe.checkout?
    assert_not Payments::InPerson.checkout?
  end

  test "payments are off until the switch is on" do
    assert_not Payments.enabled?
    Setting.set("payments_enabled", "1")
    assert Payments.enabled?
  end

  test "pay in person is enabled by default, the others need their switch and Stripe its key" do
    assert_equal %w[in_person], Payments.enabled_methods.map(&:key)

    Setting.set("payments_bank_transfer_enabled", "1")
    Setting.set("payments_stripe_enabled", "1")
    assert_equal %w[in_person bank_transfer], Payments.enabled_methods.map(&:key)

    Setting.set("payments_stripe_secret_key", "sk_test_1")
    assert_equal %w[in_person bank_transfer stripe], Payments.enabled_methods.map(&:key)
  end

  test "the default method is the setting while enabled, else the first enabled method" do
    assert_equal "in_person", Payments.default_method.key

    Setting.set("payments_default_method", "bank_transfer")
    assert_equal "in_person", Payments.default_method.key, "a disabled default does not count"

    Setting.set("payments_bank_transfer_enabled", "1")
    assert_equal "bank_transfer", Payments.default_method.key

    Setting.set("payments_in_person_enabled", "0")
    Setting.set("payments_bank_transfer_enabled", "0")
    assert_nil Payments.default_method
  end

  test "a service offers its enabled methods, or the default when it lists none" do
    service = services(:haircut)
    assert_equal %w[in_person], Payments.methods_for(service).map(&:key)

    service.payment_method_keys = %w[stripe bank_transfer]
    assert_equal %w[in_person], Payments.methods_for(service).map(&:key), "none of its methods is enabled"

    Setting.set("payments_bank_transfer_enabled", "1")
    assert_equal %w[bank_transfer], Payments.methods_for(service).map(&:key)
  end

  test "config answers stored settings with code defaults and takes overrides" do
    config = Payments.config("payments_stripe_secret_key" => "sk_posted")
    assert_equal "sk_posted", config["payments_stripe_secret_key"]
    assert_equal "GBP", config["payments_stripe_currency"]
    assert_equal "1", config["payments_in_person_enabled"]
  end

  test "instructions come from the method's setting" do
    Setting.set("payments_bank_transfer_instructions", "Sort code 12-34-56")
    assert_equal "Sort code 12-34-56", Payments::BankTransfer.instructions
    assert_equal "", Payments::InPerson.instructions
  end
end
