require "application_system_test_case"

# The Calendar and List toolbars: filter dropdowns on the left, action buttons
# on the right in one row with plain-weight labels and centred icons.
class CalendarToolbarTest < ApplicationSystemTestCase
  # Each visible action button's box, label weight and icon centre offset.
  ACTION_BOXES = <<~JS.freeze
    (() => {
      const filter = document.getElementById('calendar-filter').getBoundingClientRect();
      const toolbar = document.getElementById('calendar-toolbar').getBoundingClientRect();
      const buttons = [...document.querySelectorAll('#calendar-actions .btn')]
        .filter(button => button.offsetParent !== null);
      return { filterRight: filter.right, filterTop: filter.top, toolbarRight: toolbar.right,
               buttons: buttons.map(button => {
                 const box = button.getBoundingClientRect();
                 const icon = button.querySelector('svg');
                 const iconBox = icon && icon.getBoundingClientRect();
                 return { text: button.innerText.trim(), top: Math.round(box.top), left: box.left, right: box.right,
                          weight: getComputedStyle(button).fontWeight,
                          iconOffset: iconBox ? Math.abs((iconBox.top + iconBox.bottom) / 2 - (box.top + box.bottom) / 2) : 0 };
               }) };
    })()
  JS

  setup do
    riley = User.create!(name: "Riley", email: "riley@example.org", role: users(:zane).role, timezone: "Europe/London")
    ServiceProviderLink.create!(id_users: riley.id, id_services: services(:haircut).id)
    login_as_admin
    page.execute_script("window.localStorage.clear()") # no ticks saved by an earlier test
  end

  test "on a laptop the Calendar actions sit in one row at the right of the filters" do
    visit calendar_url
    show_only_stylist("Zane")
    assert_selector "#enable-sync", visible: true, wait: 5
    assert_selector "#calendar-feed svg[data-prefix=far][data-icon=calendar]", wait: 5
    boxes = page.evaluate_script(ACTION_BOXES)

    assert_equal [ "Enable Sync", "Feed", "Add", "Refresh" ], boxes["buttons"].map { |b| b["text"] }
    assert_one_row_at_right(boxes)
    assert_operator boxes["buttons"].first["left"], :>, boxes["filterRight"], "actions start right of the filters"

    show_sync_button_group
    boxes = page.evaluate_script(ACTION_BOXES)
    assert_equal [ "Sync", "Toggle Dropdown", "Feed", "Add", "Refresh" ], boxes["buttons"].map { |b| b["text"] }
    assert_one_row_at_right(boxes)
  end

  test "on a tablet the Calendar filters and actions share one row" do
    resize_window(1000, 900)
    visit calendar_url
    show_only_stylist("Zane")
    show_sync_button_group
    boxes = page.evaluate_script(ACTION_BOXES)

    assert_one_row_at_right(boxes)
    assert_in_delta boxes["filterTop"], boxes["buttons"].first["top"], 8, "actions beside the filters"
  end

  test "the List actions say Add and Refresh in one row at the right" do
    visit appointments_url
    assert_selector "#reload-appointments", wait: 5
    boxes = page.evaluate_script(ACTION_BOXES)

    assert_equal [ "Add", "Refresh" ], boxes["buttons"].map { |b| b["text"] }
    assert_one_row_at_right(boxes)
  end

  private

  # Synced stylists show Sync and its menu toggle in place of Enable Sync.
  def show_sync_button_group
    page.execute_script("$('#enable-sync').prop('hidden', true); $('#sync-button-group').prop('hidden', false)")
  end

  def assert_one_row_at_right(boxes)
    buttons = boxes["buttons"]
    assert_equal [ buttons.first["top"] ], buttons.map { |b| b["top"] }.uniq, "action buttons in one row"
    assert_in_delta boxes["toolbarRight"], buttons.last["right"], 24, "last action button against the right edge"
    buttons.each do |button|
      assert_equal "400", button["weight"], "#{button['text']} label weight"
      assert_operator button["iconOffset"], :<=, 1, "#{button['text']} icon centred"
    end
  end
end
