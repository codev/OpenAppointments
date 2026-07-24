# WCAG 2 contrast math, mirrored by App.Utils.Contrast in the JS.
module ColorContrast
  AA_NORMAL = 4.5

  module_function

  def ratio(hex_a, hex_b)
    la = relative_luminance(hex_a)
    lb = relative_luminance(hex_b)
    hi, lo = [ la, lb ].max, [ la, lb ].min
    ((hi + 0.05) / (lo + 0.05)).round(2)
  end

  def aa?(hex_a, hex_b)
    ratio(hex_a, hex_b) >= AA_NORMAL
  end

  def relative_luminance(hex)
    hex = hex.to_s.delete_prefix("#")
    hex = hex.chars.map { |char| char * 2 }.join if hex.length == 3
    r, g, b = hex.scan(/../).map do |pair|
      channel = pair.to_i(16) / 255.0
      channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end
end
