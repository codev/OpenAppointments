module ApplicationHelper
  # The stored theme, sanitized: anything unknown (stale cache, retired theme)
  # falls back to the default so layouts never reference a missing stylesheet.
  def active_theme(requested = nil)
    theme = requested.presence || setting("theme").presence || "nice"
    Themes::SLUGS.include?(theme) ? theme : "nice"
  end
end
