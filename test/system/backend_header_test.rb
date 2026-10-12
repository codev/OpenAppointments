require "application_system_test_case"

# The compact admin header (768 to 1199px): icons above labels, every icon
# starting at the same height, each icon centred over its label, and the
# dropdown caret centred under the label.
class BackendHeaderTest < ApplicationSystemTestCase
  # Text nodes have no box of their own: a Range gives the label's rect.
  MEASURE = <<~JS.freeze
    return Array.from(document.querySelectorAll('#header .navbar-nav .nav-link')).map((link) => {
      const icon = link.querySelector('i, svg');
      const text = Array.from(link.childNodes).find((n) => n.nodeType === 3 && n.textContent.trim());
      let label = null;
      if (text) {
        const range = document.createRange();
        range.selectNodeContents(text);
        const r = range.getBoundingClientRect();
        label = { left: r.left, right: r.right, top: r.top, bottom: r.bottom };
      }
      const i = icon.getBoundingClientRect();
      const after = getComputedStyle(link, '::after');
      return {
        direction: getComputedStyle(link).flexDirection,
        iconTop: i.top, iconCentre: (i.left + i.right) / 2,
        label: label,
        caretMarginLeft: after.marginLeft, caretDisplay: after.display,
        linkCentre: (link.getBoundingClientRect().left + link.getBoundingClientRect().right) / 2
      };
    });
  JS

  def measure_at(width)
    resize_window(width, 900)
    assert_selector "#header .navbar-nav .nav-link", wait: 5
    page.evaluate_script("(() => { #{MEASURE} })()")
  end

  test "icons stack over centred labels with aligned tops across the compact range" do
    login_as_admin
    [ 800, 1150 ].each do |width|
      links = measure_at(width)
      assert links.all? { |l| l["direction"] == "column" }, "#{width}px: expected stacked links"
      tops = links.map { |l| l["iconTop"].round }
      assert_operator tops.max - tops.min, :<=, 1, "#{width}px: icon tops differ #{tops.inspect}"
      links.select { |l| l["label"] }.each do |l|
        label_centre = (l["label"]["left"] + l["label"]["right"]) / 2
        assert_in_delta label_centre, l["iconCentre"], 2, "#{width}px: icon not centred over its label"
      end
      links.select { |l| l["caretDisplay"] != "none" }.each do |l|
        assert_equal "0px", l["caretMarginLeft"], "#{width}px: caret is pushed off centre"
      end
    end
  end

  # The caret sits right under the last row of a stacked dropdown link (the
  # label, or the icon when there is none), so equal last-row bottoms mean the
  # carets line up, the cog included.
  test "dropdown carets line up across the compact range" do
    login_as_admin
    [ 800, 1150 ].each do |width|
      resize_window(width, 900)
      assert_selector "#header .navbar-nav .dropdown-toggle", wait: 5
      bottoms = page.evaluate_script(<<~JS).map(&:round)
        Array.from(document.querySelectorAll('#header .navbar-nav .nav-item:not(.d-none) > .dropdown-toggle'))
          .map((link) => {
            const rows = Array.from(link.childNodes).filter((n) =>
              n.nodeType === 1 ? getComputedStyle(n).display !== 'none' : n.nodeType === 3 && n.textContent.trim());
            const range = document.createRange();
            range.selectNode(rows[rows.length - 1]);
            return range.getBoundingClientRect().bottom;
          })
      JS
      assert_operator bottoms.size, :>=, 3
      assert_operator bottoms.max - bottoms.min, :<=, 1, "#{width}px: caret rows differ #{bottoms.inspect}"
    end
  end

  test "the Calendar and List toolbars use the theme header colours" do
    login_as_admin
    [ "/calendar", "/appointments" ].each do |path|
      visit path
      assert_selector "#calendar-toolbar", wait: 10
      colours = page.evaluate_script(<<~JS)
        (() => {
          const style = (id) => getComputedStyle(document.getElementById(id));
          const link = getComputedStyle(document.querySelector('#header .nav-link'));
          return { header: [style('header').backgroundColor, link.color],
                   toolbar: [style('calendar-toolbar').backgroundColor, style('calendar-toolbar').color] };
        })()
      JS
      assert_equal colours["header"][0], colours["toolbar"][0], "#{path}: toolbar background"
      assert_equal colours["header"][1], colours["toolbar"][1], "#{path}: toolbar text"
    end
  end

  test "labels sit beside icons again from 1200px" do
    login_as_admin
    links = measure_at(1250)
    assert links.all? { |l| l["direction"] == "row" }, "1250px: expected inline links"
  end
end
