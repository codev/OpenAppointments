require "test_helper"

# Step indicator markup: numbered chips with a hidden check, clickable when completed.
class BookingStepsTest < ActionDispatch::IntegrationTest
  test "the wizard header renders five indexed steps with numbers and checks" do
    get "/"
    assert_select "#steps li.book-step", 5
    (1..5).each do |i|
      assert_select "#steps #step-#{i}[data-step-index='#{i}'] .step-number", text: i.to_s
      assert_select "#steps #step-#{i} .step-check"
    end
    assert_select "#steps #step-1[aria-current=step].active-step"
    assert_select "#steps [aria-current=step]", 1
  end
end
