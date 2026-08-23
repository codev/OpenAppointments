require "application_system_test_case"

# Repeating appointments panel on the appointments page. Written against the
# jQuery version (labels, visible text and ids), so it must pass on both.
class AppointmentSeriesPageTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Setting.set("future_booking_limit", "40")
    appointment = appointments(:upcoming)
    repeat = { "rule" => { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [ 1 ] } }.to_json,
               "ends" => "never" }
    travel_to Time.new(2026, 7, 20, 8, 0, 0) do
      @series = AppointmentSeries.start_from(appointment, repeat)[:series]
    end
    login_as_admin
  end

  test "the panel lists the series and cancels it from a chosen date" do
    travel_to Time.new(2026, 7, 20, 9, 0, 0) do
      visit appointments_url
      assert_selector "#toggle-series", wait: 5
      click_on "Repeating Appointments"
      assert_selector "#series-table tbody tr", count: 1, wait: 5
      assert_selector "#series-table", text: "Zane"
      assert_selector "#series-table", text: "JX"
      assert_selector "#series-table", text: "Trim Cut"
      assert_selector "#series-table", text: "10:00"
      assert_text "Back to Appointments"

      click_on "Cancel series"
      assert_selector "#series-cancel-confirm", visible: true, wait: 5
      within(find("#series-cancel-confirm").ancestor("form, .modal")) do
        assert_selector "#series-cancel-dates input[type=radio]", minimum: 2, visible: :all
        all("#series-cancel-dates input[type=radio]", visible: :all)[1].click
        fill_in "series-cancel-reason", with: "Away"
        uncheck "series-cancel-notify"
        click_on "Cancel from this date"
      end
      assert_text "Repeating appointments cancelled", wait: 5
      assert_equal [ Date.new(2026, 7, 20) ], @series.reload.appointments.active.pluck(:occurrence_at)
      assert_operator @series.ends_on, :<, Date.new(2026, 7, 27)

      click_on "Back to Appointments"
      assert_selector "#calendar .calendar-view", visible: true, wait: 5
      assert_selector "#series-view", visible: false
    end
  end
end
