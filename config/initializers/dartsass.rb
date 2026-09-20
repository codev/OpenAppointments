# Stylesheet builds: the Pico-based booking and admin sheets plus the seven
# themes, each a file of token overrides and a few element rules.
themes = %w[brutalism coder fruit material nice outline solid]

Rails.application.config.dartsass.builds = {
  "oa/backend.scss" => "oa-backend.css",
  "oa/booking.scss" => "oa-booking.css"
}.merge(themes.to_h { |theme| [ "oa/themes/#{theme}.scss", "oa-themes/#{theme}.css" ] })

Rails.application.config.dartsass.build_options = %w[--style=compressed --no-source-map --quiet-deps
                                                     --silence-deprecation=import --silence-deprecation=global-builtin]
