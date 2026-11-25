require "application_system_test_case"

# The Calendar's Day view: one column per stylist working that day or with an
# appointment that day, scrolling sideways when they do not fit, each column
# greyed by its own stylist's working plan.
class CalendarDayColumnsTest < ApplicationSystemTestCase
  DAY_VIEW = ".fc-resourceTimeGridDay-view".freeze

  # Header cells and columns by stylist name: {name => {left, right}} in page pixels.
  COLUMNS = <<~JS.freeze
    Object.fromEntries([...document.querySelectorAll('#calendar .fc-col-header-cell.fc-resource')]
      .map((cell) => { const box = cell.getBoundingClientRect();
                       return [cell.innerText.trim(), { left: box.left, right: box.right, id: cell.dataset.resourceId }]; }))
  JS

  def stylist(name, plan: users(:zane).settings.working_plan, service: services(:haircut))
    user = User.create!(name: name, email: "#{name.downcase}@example.org", role: users(:zane).role, timezone: "Europe/London")
    user.create_settings!(username: name.downcase, password: Passwords.hash("stylistpass1"), working_plan: plan)
    ServiceProviderLink.create!(id_users: user.id, id_services: service.id)
    user
  end

  def book(provider, start, customer: users(:jx))
    Appointment.create!(provider: provider, customer: customer, service: services(:haircut),
                        start_datetime: start, end_datetime: start + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
  end

  # Every ticked stylist, and the Day view on the given date.
  def open_day(date)
    page.execute_script("window.localStorage.clear()")
    visit calendar_url
    find(".fc-resourceTimeGridDay-button", wait: 10).click
    page.execute_script("$('#calendar').data('fullCalendar').gotoDate(arguments[0])", date.to_s)
    assert_selector DAY_VIEW, wait: 10
    assert_selector "#calendar .fc-col-header-cell.fc-resource", wait: 10
  end

  def columns = page.evaluate_script(COLUMNS)

  def within_column?(box, column) = box["left"] >= column["left"] - 1 && box["right"] <= column["right"] + 1

  def event_box(text)
    page.evaluate_script(<<~JS, text)
      (() => { const el = [...document.querySelectorAll('#calendar .fc-timegrid-event')].find((e) => e.textContent.includes(arguments[0]));
               if (!el) return null; const box = el.getBoundingClientRect(); return { left: box.left, right: box.right }; })()
    JS
  end

  setup do
    login_as_admin
    @day = working_day
    @riley = stylist("Riley")
    # Nico works no day of the week but has an appointment; Ola neither.
    off = users(:zane).working_plan.transform_values { nil }.to_json
    @nico = stylist("Nico", plan: off)
    stylist("Ola", plan: off)
    book(@nico, Time.zone.parse("#{@day} 11:00"))
    @zanes = book(users(:zane), Time.zone.parse("#{@day} 10:00"))
  end

  test "the Day view has a column for every stylist working or booked that day, by name" do
    open_day(@day)
    assert_equal [ "Nico", "Riley", "Zane" ], columns.keys
    assert_equal users(:zane).id.to_s, columns["Zane"]["id"]
    assert_equal false, page.evaluate_script("$('#calendar').data('fullCalendar').getOption('eventResourceEditable')"),
                 "an appointment is not dragged into another stylist's column"
  end

  test "each appointment sits in its stylist's column" do
    open_day(@day)
    assert_selector "#calendar .fc-timegrid-event", text: "JX", count: 2, wait: 10
    boxes = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('#calendar .fc-timegrid-event')]
        .map((el) => { const box = el.getBoundingClientRect(); return { left: box.left, right: box.right }; })
        .sort((a, b) => a.left - b.left)
    JS
    cols = columns
    assert within_column?(boxes[0], cols["Nico"]), "first appointment in Nico's column: #{boxes[0]} #{cols['Nico']}"
    assert within_column?(boxes[1], cols["Zane"]), "second appointment in Zane's column: #{boxes[1]} #{cols['Zane']}"
  end

  test "a stylist off all day is greyed from top to bottom, a working one only outside their hours" do
    open_day(@day)
    cover = page.evaluate_script(<<~JS)
      (() => {
        const cols = #{COLUMNS};
        const body = document.querySelector('#calendar .fc-timegrid-body').getBoundingClientRect();
        const cover = {};
        document.querySelectorAll('#calendar .fc-timegrid-col .fc-bg-event').forEach((el) => {
          const box = el.getBoundingClientRect();
          const name = Object.keys(cols).find((n) => box.left >= cols[n].left - 1 && box.right <= cols[n].right + 1);
          cover[name] = (cover[name] || 0) + (box.bottom - box.top) / body.height;
        });
        return cover;
      })()
    JS
    assert_operator cover["Nico"], :>=, 0.95, "Nico's column greyed all day: #{cover}"
    assert_operator cover["Zane"] || 0, :<, 0.5, "Zane's column greyed outside working hours only: #{cover}"
  end

  test "with many stylists the day scrolls sideways and keeps the time axis in view" do
    %w[Ash Bea Cal Dev Eli Fay].each { |name| stylist(name) }
    open_day(@day)
    assert_selector "#calendar .fc-col-header-cell.fc-resource", count: 9, wait: 10
    scroll = page.evaluate_script(<<~JS)
      (() => {
        const scroller = [...document.querySelectorAll('#calendar .fc-scroller')].find((s) => s.scrollWidth > s.clientWidth + 1);
        if (!scroller) return null;
        scroller.scrollLeft = scroller.scrollWidth;
        const axis = document.querySelector('#calendar .fc-timegrid-axis').getBoundingClientRect();
        const calendar = document.getElementById('calendar').getBoundingClientRect();
        return { overflow: scroller.scrollWidth - scroller.clientWidth, axisVisible: axis.left >= calendar.left && axis.right <= calendar.right };
      })()
    JS
    refute_nil scroll, "expected a horizontally scrolling grid"
    assert_operator scroll["overflow"], :>, 100
    assert scroll["axisVisible"], "time axis stays on screen when scrolled right"
  end

  test "selecting a slot in a column starts an appointment for that stylist" do
    open_day(@day)
    start = "#{@day}T12:00:00"
    page.execute_script("$('#calendar').data('fullCalendar').select({ start: arguments[0], end: arguments[1], resourceId: arguments[2] })",
                        start, "#{@day}T12:30:00", @riley.id.to_s)
    assert_selector "#message-modal.show", text: "Add New Event", wait: 10
    within("#message-modal .modal-footer") { click_on "Appointment" }
    assert_selector "#select-provider", wait: 10
    assert_equal @riley.id.to_s, find("#select-provider").value
  end

  test "the last used view is remembered per browser" do
    open_day(@day)
    visit calendar_url
    assert_selector DAY_VIEW, wait: 10
    find(".fc-timeGridWeek-button").click
    assert_selector ".fc-timeGridWeek-view", wait: 10
    visit calendar_url
    assert_selector ".fc-timeGridWeek-view", wait: 10
    assert_no_selector DAY_VIEW
  end
end
