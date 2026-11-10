# One Booking Notice per booking step replaces the single notice with two
# display switches: the old text lands on each step whose switch was on.
class SplitBookingNotice < ActiveRecord::Migration[8.1]
  OLD = %w[booking_notice_content display_booking_notice_time_step display_booking_notice_info_step].freeze

  def up
    content = Setting.get("booking_notice_content")
    Setting.set("booking_notice_time_content", content) if Setting.get("display_booking_notice_time_step") == "1"
    Setting.set("booking_notice_info_content", content) if Setting.get("display_booking_notice_info_step") == "1"
    Setting.where(name: OLD).delete_all
  end

  def down; end
end
