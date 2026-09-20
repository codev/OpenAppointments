require "test_helper"

# The style guide lists every semantic component on the Pico layout.
class StyleguideTest < ActionDispatch::IntegrationTest
  test "the guide renders each component on the pico layout with the theme" do
    get "/styleguide"
    assert_response :success
    assert_select "body.pico"
    assert_select "link[href*='pico.conditional']"
    assert_select "link[href*='oa-backend']"
    assert_select "link[href*='oa-themes/nice']"
    %w[.app-header .page .with-sidebar .side-nav .actions .fields .field .field-hint .notice .count .tag
       .panel details.menu [role=tablist] dialog .record-list table.striped .legend .loading].each do |selector|
      assert_select selector, minimum: 1
    end
    assert_select ".notice[data-tone=error][role=alert]"
    assert_select "[aria-invalid=true]"
  end
end
