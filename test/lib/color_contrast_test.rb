require "test_helper"

class ColorContrastTest < ActiveSupport::TestCase
  test "black on white is 21 and white on white is 1" do
    assert_equal 21.0, ColorContrast.ratio("#000000", "#ffffff")
    assert_equal 1.0, ColorContrast.ratio("#ffffff", "#fff")
  end

  test "aa? uses the 4.5 normal text threshold" do
    assert ColorContrast.aa?("#39824f", "#ffffff") # 4.99
    assert_not ColorContrast.aa?("#dd2a5c", "#f2f6fa") # 4.2ish? guard direction only
  end

  test "every suggested theme palette passes WCAG AA on all pairings" do
    Themes::SUGGESTED.each do |theme, palette|
      primary = palette["primary"]
      secondary = palette["secondary"]
      background = palette["background"]
      {
        "white on primary" => [ "#ffffff", primary ],
        "primary on background" => [ primary, background ],
        "white on secondary" => [ "#ffffff", secondary ],
        "secondary on background" => [ secondary, background ],
        "body text on background" => [ "#212529", background ]
      }.each do |label, (a, b)|
        assert ColorContrast.aa?(a, b),
               "#{theme}: #{label} fails (#{ColorContrast.ratio(a, b)}:1)"
      end
    end
  end

  test "suggestions exist for every theme" do
    assert_equal Themes::SLUGS.sort, Themes::SUGGESTED.keys.sort
  end
end
