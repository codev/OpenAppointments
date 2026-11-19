# Payment method registry. A method is a module with key/label/checkout?/
# enabled?/instructions; checkout methods also create and read payment sessions.
module Payments
  module_function

  def all
    [ Payments::InPerson, Payments::BankTransfer, Payments::Stripe ]
  end

  def find(key)
    all.find { |method| method.key == key.to_s }
  end

  def enabled_methods
    all.select(&:enabled?)
  end

  # Global switch on Payments > Settings: off, the booking flow says nothing
  # about payment and appointments record no method.
  def enabled?
    Setting.get("payments_enabled", Payments::Defaults::SETTINGS["payments_enabled"]) == "1"
  end

  def default_method_key
    Setting.get("payments_default_method", Payments::Defaults::SETTINGS["payments_default_method"]).to_s
  end

  # The method offered by services that list none: the chosen default while it
  # is enabled, else the first enabled method.
  def default_method
    enabled_methods.find { |method| method.key == default_method_key } || enabled_methods.first
  end

  # The enabled methods a service accepts, or the default when it lists none
  # that are enabled. A checkout method has nothing to charge for a free
  # service, so it is left out.
  def methods_for(service)
    offered = enabled_methods.reject { |method| method.checkout? && service.price.to_f <= 0 }
    chosen = offered.select { |method| service.payment_method_keys.include?(method.key) }
    chosen.presence || [ default_method ].compact
  end

  # A method's configuration: stored settings with the code defaults, overlaid
  # with posted values for the settings page tests.
  def config(overrides = {})
    Hash.new { |_, name| Setting.get(name, Payments::Defaults::SETTINGS[name]).to_s }.merge(overrides)
  end
end
