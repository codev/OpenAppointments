require "application_system_test_case"

# Cards mode: choosing a category reveals its description under the category
# cards and scrolls to it, so the explainer is read before the services.
class BookingCategoryDescriptionTest < ApplicationSystemTestCase
  test "clicking a category shows its description and scrolls to it" do
    Setting.set("booking_display_mode", "cards")
    resize_window(1000, 450)
    visit root_url
    assert_selector "#category-cards .booking-card", minimum: 1
    assert_no_selector "#category-description .selection-description", visible: :visible

    find("#category-cards .booking-card[data-category-id='#{service_categories(:hair).id}']").click
    assert_selector "#category-description .selection-description", text: "Hair services", visible: :visible
    assert 20.times.any? { description_at_top? || (sleep(0.1) && false) }, "the description did not scroll into view"
  end

  def description_at_top?
    top = page.evaluate_script("document.querySelector('#category-description .selection-description:not(.d-none)').getBoundingClientRect().top")
    top.between?(0, 60)
  end
end
