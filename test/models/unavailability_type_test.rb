require "test_helper"

class UnavailabilityTypeTest < ActiveSupport::TestCase
  test "ordered by position, names unique, rows for the forms" do
    assert_equal [ "Meeting", "Time off" ], UnavailabilityType.ordered.pluck(:name)
    assert_not UnavailabilityType.new(name: "Meeting").valid?
    assert_not UnavailabilityType.new(name: "").valid?
    assert_equal({ "id" => unavailability_types(:meeting).id, "name" => "Meeting", "color" => "#7cbae8" }, UnavailabilityType.rows.first)
  end

  test "resolve finds by name or creates at the end; seed! fills the default list once" do
    assert_equal unavailability_types(:meeting), UnavailabilityType.resolve("Meeting")
    travel = UnavailabilityType.resolve("Travel", color: "#123456")
    assert_equal [ "#123456", 2 ], [ travel.color, travel.position ]
    assert_nil UnavailabilityType.resolve(" ")

    UnavailabilityType.seed!
    assert_equal [ "Meeting", "Time off", "Travel", "Admin" ], UnavailabilityType.ordered.pluck(:name)
    assert_no_difference("UnavailabilityType.count") { UnavailabilityType.seed! }
  end

  test "deleting a type keeps its busy times without a type" do
    block = appointments(:lunch_block)
    block.update!(unavailability_type: unavailability_types(:meeting))
    unavailability_types(:meeting).destroy!
    assert_nil block.reload.unavailability_type_id
  end
end
