# Payments > Methods: cards per method with the active state and a link to
# each method's settings page.
class PaymentsMethodsController < ApplicationController
  include BackendPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("payments"), active_menu: "payments")
    html_vars(method_cards: method_cards)
    render :index
  end

  private

  def method_cards
    Payments.all.map do |method|
      {
        key: method.key,
        label: method.label,
        settings_path: "/payments_#{method.key}_settings",
        enabled: method.enabled?,
        default: method == Payments.default_method
      }
    end
  end
end
