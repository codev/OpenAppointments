# Theme registry: the seven built themes and a suggested brand palette per
# theme. Every suggested palette passes WCAG AA for white-on-primary,
# primary-on-background, white-on-secondary, secondary-on-background and
# body-text-on-background (guarded by test).
module Themes
  SLUGS = %w[brutalism coder fruit material nice outline solid].freeze

  SUGGESTED = {
    "nice" => { "primary" => "#337346", "secondary" => "#c22450", "background" => "#f2f6fa" },
    "material" => { "primary" => "#6750a4", "secondary" => "#8b3a62", "background" => "#fef7ff" },
    "coder" => { "primary" => "#176f32", "secondary" => "#0757b4", "background" => "#f6f8fa" },
    "fruit" => { "primary" => "#0064c8", "secondary" => "#1d1d1f", "background" => "#f5f5f7" },
    "brutalism" => { "primary" => "#000000", "secondary" => "#c62f2c", "background" => "#ffffff" },
    "outline" => { "primary" => "#39824f", "secondary" => "#b02a37", "background" => "#ffffff" },
    "solid" => { "primary" => "#6b5c6e", "secondary" => "#a83f38", "background" => "#f6ece4" }
  }.freeze
end
