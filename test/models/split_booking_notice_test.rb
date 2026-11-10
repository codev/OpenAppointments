require "test_helper"

# The single Booking Notice with two display switches becomes one notice per
# step: the old text lands on each step whose switch was on, and the old rows go.
class SplitBookingNoticeTest < ActiveSupport::TestCase
  MIGRATION = Rails.root.glob("db/migrate/*_split_booking_notice.rb").first
  OLD = %w[booking_notice_content display_booking_notice_time_step display_booking_notice_info_step].freeze

  def migrate(content, time_switch, info_switch)
    require MIGRATION
    Setting.set("booking_notice_content", content)
    Setting.set("display_booking_notice_time_step", time_switch)
    Setting.set("display_booking_notice_info_step", info_switch)
    ActiveRecord::Migration.suppress_messages { SplitBookingNotice.new.up }
  end

  test "the text moves to the steps whose switch was on" do
    migrate("<p>Two weeks ahead.</p>", "1", "0")
    assert_equal "<p>Two weeks ahead.</p>", Setting.get("booking_notice_time_content")
    assert_nil Setting.get("booking_notice_info_content")
  end

  test "both switches on copies the text to both steps" do
    migrate("<p>Policy.</p>", "1", "1")
    assert_equal "<p>Policy.</p>", Setting.get("booking_notice_time_content")
    assert_equal "<p>Policy.</p>", Setting.get("booking_notice_info_content")
  end

  test "a notice that was not displayed is not carried over" do
    migrate("<p>Hidden.</p>", "0", "0")
    assert_nil Setting.get("booking_notice_time_content")
    assert_nil Setting.get("booking_notice_info_content")
  end

  test "the old setting rows are removed" do
    migrate("<p>Gone.</p>", "1", "1")
    assert_empty Setting.where(name: OLD)
  end

  test "seeds hold the five notices and none of the old rows" do
    seeds = Rails.root.join("db/seeds.rb").read
    %w[service provider time info final].each { |step| assert_match(/"booking_notice_#{step}_content" => ""/, seeds) }
    OLD.each { |name| assert_no_match(/"#{name}"/, seeds) }
  end
end
