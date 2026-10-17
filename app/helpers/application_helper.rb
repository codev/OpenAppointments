module ApplicationHelper
  # The stored theme, sanitized: anything unknown (stale cache, retired theme)
  # falls back to the default so layouts never reference a missing stylesheet.
  def active_theme(requested = nil)
    theme = requested.presence || setting("theme").presence || "nice"
    Themes::SLUGS.include?(theme) ? theme : "nice"
  end

  # The top bar colour for the phone status bar: the company background colour
  # for the themes whose top bar uses it, the company colour for the rest.
  def theme_color(theme = active_theme)
    Themes::BACKGROUND_BAR.include?(theme) ? brand_background_color : brand_primary_color
  end
end
