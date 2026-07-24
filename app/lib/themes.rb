# Theme registry: the seven built themes, two suggested brand palettes per
# theme (the first leans on the Open Out brand colours, the second is
# theme-native) and which themes scope the background colour to the top bar
# only. Every suggested palette passes WCAG AA on all pairings (guarded by
# test).
module Themes
  SLUGS = %w[brutalism coder fruit material nice outline solid].freeze

  # Themes where the background colour paints only the header; the page stays white.
  HEADER_SCOPED_BACKGROUND = %w[coder fruit].freeze

  SUGGESTED = {
    "nice" => [
      { "primary" => "#337346", "secondary" => "#c22450", "background" => "#f2f6fa" },
      { "primary" => "#325b8c", "secondary" => "#b3336b", "background" => "#f7f5f2" }
    ],
    "material" => [
      { "primary" => "#2e6b3f", "secondary" => "#c22450", "background" => "#f7fbf4" },
      { "primary" => "#6750a4", "secondary" => "#8b3a62", "background" => "#fef7ff" }
    ],
    "coder" => [
      { "primary" => "#176f32", "secondary" => "#c22450", "background" => "#f6f8fa" },
      { "primary" => "#0757b4", "secondary" => "#6639ba", "background" => "#ffffff" }
    ],
    "fruit" => [
      { "primary" => "#337346", "secondary" => "#c22450", "background" => "#f5f5f7" },
      { "primary" => "#0064c8", "secondary" => "#1d1d1f", "background" => "#f5f5f7" }
    ],
    "brutalism" => [
      { "primary" => "#14532d", "secondary" => "#c22450", "background" => "#ffffff" },
      { "primary" => "#000000", "secondary" => "#c62f2c", "background" => "#ffffff" }
    ],
    "outline" => [
      { "primary" => "#39824f", "secondary" => "#b02a37", "background" => "#ffffff" },
      { "primary" => "#1f2937", "secondary" => "#0757b4", "background" => "#ffffff" }
    ],
    "solid" => [
      { "primary" => "#337346", "secondary" => "#c22450", "background" => "#fdf1ec" },
      { "primary" => "#6b5c6e", "secondary" => "#a83f38", "background" => "#f6ece4" }
    ]
  }.freeze
end
