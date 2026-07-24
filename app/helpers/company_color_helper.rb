# Color math for shared/_brand_style (hex_to_rgb, adjust_brightness), plus the
# WCAG contrast helpers used by the settings accessibility checks.
module CompanyColorHelper
  DEFAULT_COMPANY_COLOR = "#ffffff"

  private

  # "#35A768" -> "53, 167, 104"
  def hex_to_rgb(hex)
    expand_hex(hex).scan(/../).map { |pair| pair.to_i(16) }.join(", ")
  end

  # Positive percent lightens, negative darkens. "#35A768", 15 -> "#3dc077"
  def adjust_brightness(hex, percent)
    channels = expand_hex(hex).scan(/../).map do |pair|
      value = pair.to_i(16)
      (value + value * percent / 100.0).clamp(0, 255).to_i
    end
    format("#%02x%02x%02x", *channels)
  end

  def expand_hex(hex)
    hex = hex.to_s.delete_prefix("#")
    hex = hex.chars.map { |char| char * 2 }.join if hex.length == 3
    hex
  end
end
