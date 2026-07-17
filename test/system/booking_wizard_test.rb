require "application_system_test_case"

class BookingWizardTest < ApplicationSystemTestCase
  test "service first navigation reaches the time step" do
    visit root_url
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    assert_selector "#select-service", visible: :visible

    select services(:haircut).name, from: "select-service"
    find("#button-next-1").click

    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
    select users(:jane).name, from: "select-provider"
    find("#button-next-2").click

    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
    # flatpickr swaps the date input for its own alt input, so #select-date stays hidden.
    assert_selector "#select-date", visible: :all

    find("#button-back-3").click
    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
  end

  test "provider first navigation reaches the time step" do
    visit root_url(first: "provider")
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    assert_selector "#select-provider", visible: :visible

    select users(:jane).name, from: "select-provider"
    find("#button-next-1").click

    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
    select services(:haircut).name, from: "select-service"
    find("#button-next-2").click

    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
  end

  test "first page blocks next until a choice is made" do
    visit root_url
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    find("#button-next-1").click
    assert_selector "#wizard-frame-1", visible: :visible
    assert_no_selector "#wizard-frame-2", visible: :visible
  end
end
