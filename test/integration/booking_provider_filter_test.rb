require "test_helper"

# Provider first: the service step lists only the services that provider
# offers, and in cards mode only the categories those services belong to.
class BookingProviderFilterTest < ActionDispatch::IntegrationTest
  setup do
    @colour = ServiceCategory.create!(name: "Colour")
    @tint = Service.create!(name: "Tint", duration: 60, price: 0, currency: "GBP", slot_interval: 30,
                            attendants_number: 1, category: @colour)
    @riley = User.create!(name: "Riley", email: "riley@example.org", role: users(:zane).role)
    ServiceProviderLink.create!(provider: @riley, service: @tint)
  end

  def service_step(provider)
    get "/", params: { first: "provider", step: "second", provider_id: provider.id }
    assert_response :success
  end

  def listed_service_ids
    css_select("#select-service option").map { |o| o["value"].to_i }.reject(&:zero?)
  end

  test "dropdown lists only the chosen provider's services" do
    Setting.set("booking_display_mode", "dropdown")
    service_step(users(:zane))
    assert_equal [ services(:group_session).id, services(:haircut).id ].sort, listed_service_ids.sort
    service_step(@riley)
    assert_equal [ @tint.id ], listed_service_ids
  end

  test "cards show only the chosen provider's services and their categories" do
    Setting.set("booking_display_mode", "cards")
    service_step(users(:zane))
    assert_select ".booking-card[data-service-id='#{@tint.id}']", 0
    assert_select ".booking-card[data-category-id='#{@colour.id}']:not([data-service-id])", 0
    assert_select ".booking-card[data-category-id='#{service_categories(:hair).id}']:not([data-service-id])", 1
    service_step(@riley)
    assert_select ".booking-card[data-service-id='#{@tint.id}']", 1
    assert_select ".booking-card[data-service-id='#{services(:haircut).id}']", 0
    assert_select ".booking-card[data-category-id='#{service_categories(:hair).id}']:not([data-service-id])", 0
  end
end
