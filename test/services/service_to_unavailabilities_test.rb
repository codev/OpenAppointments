require "test_helper"
require "rake"

# Meetings booked as a hidden service on a house customer become typed busy
# time, one group per shared slot, with their reminder records gone.
class ServiceToUnavailabilitiesTest < ActiveSupport::TestCase
  setup do
    @meeting = Service.create!(name: "A1 - Meeting", duration: 60, is_private: true, color: "#abe9a4")
    @house = User.create!(name: "Open Out", email: "house@example.org", role: users(:jx).role)
    @other = User.create!(name: "Other", email: "other@example.org", role: users(:zane).role)
    book = lambda do |provider, start, notes|
      Appointment.create!(provider: provider, customer: @house, service: @meeting, status: "Booked", notes: notes,
                          start_datetime: start, end_datetime: start + 1.hour)
    end
    @team = [ book.call(users(:zane), Time.new(2026, 12, 3, 14, 0, 0), "All staff"), book.call(@other, Time.new(2026, 12, 3, 14, 0, 0), "All staff") ]
    @solo = book.call(users(:zane), Time.new(2026, 12, 8, 13, 0, 0), "Probation")
    notification = Notification.create!(title: "Reminder", event: "coming_up", lead_mode: "before", lead_days: 1, lead_hours: 0,
                                        audiences: %w[customer], channels: %w[email], short_text: "See you")
    NotificationDispatch.record!(notification, @solo)
  end

  test "a dry run counts and changes nothing" do
    result = ServiceToUnavailabilities.run(@meeting, "Staff meeting", dry_run: true)
    assert_equal({ type: "Staff meeting", converted: 3, groups: 2, dispatches: 1 }, result)
    assert_equal 3, @meeting.appointments.count
    assert_nil UnavailabilityType.find_by(name: "Staff meeting")
  end

  test "the rows become busy time of the type, grouped by slot, without customer, service, status or reminders" do
    assert_no_difference("ActivityEvent.count") do
      ServiceToUnavailabilities.run(@meeting, "Staff meeting")
    end
    type = UnavailabilityType.find_by!(name: "Staff meeting")
    assert_equal "#abe9a4", type.color
    rows = Appointment.unavailabilities.where(unavailability_type: type).order(:id).to_a
    assert_equal 3, rows.size
    assert rows.all? { |row| row.id_users_customer.nil? && row.id_services.nil? && row.status_id.nil? }
    assert_equal [ "All staff", "All staff", "Probation" ], rows.map(&:notes)
    assert_equal rows[0].unavailability_group, rows[1].unavailability_group
    assert_not_equal rows[0].unavailability_group, rows[2].unavailability_group
    assert_equal [ users(:zane).id, @other.id ], rows.first(2).map(&:id_users_provider)
    assert_equal 0, Appointment.appointments.where(id_services: @meeting.id).count
    assert_equal 0, NotificationDispatch.where(appointment_id: @solo.id).count
    assert @meeting.reload.persisted?
  end

  test "the rake task prints the outcome and honours DRY_RUN" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("openappointments:service_to_unavailabilities")
    ENV["DRY_RUN"] = "1"
    assert_output(/A1 - Meeting: 3 appointment\(s\) would become Staff meeting busy time in 2 group\(s\), 1 reminder record\(s\) removed/) do
      Rake::Task["openappointments:service_to_unavailabilities"].execute(Rake::TaskArguments.new(%i[service_id type_name], [ @meeting.id.to_s, "Staff meeting" ]))
    end
    assert_equal 0, Appointment.unavailabilities.where.not(unavailability_type_id: nil).count
    ENV.delete("DRY_RUN")
    assert_output(/3 appointment\(s\) became Staff meeting busy time/) do
      Rake::Task["openappointments:service_to_unavailabilities"].execute(Rake::TaskArguments.new(%i[service_id type_name], [ @meeting.id.to_s, "Staff meeting" ]))
    end
    assert_equal 3, Appointment.unavailabilities.where(unavailability_type: UnavailabilityType.find_by!(name: "Staff meeting")).count
  ensure
    ENV.delete("DRY_RUN")
  end
end
