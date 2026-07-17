# EA stylesheet builds: general/frontend/backend plus 10 themes, mirroring the
# gulp styles task. Bootstrap SCSS source lives in vendor/stylesheets/bootstrap
# (themes @import 'bootstrap' via the load path).
themes = %w[cosmo darkly default flatly litera lumen materia minty sketchy zephyr]

Rails.application.config.dartsass.builds = {
  "application.scss" => "application.css",
  "ea/general.scss" => "general.css",
  "ea/frontend.scss" => "frontend.css",
  "ea/backend.scss" => "backend.css"
}.merge(themes.to_h { |theme| [ "ea/themes/#{theme}.scss", "themes/#{theme}.css" ] })

Rails.application.config.dartsass.build_options = %w[--style=compressed --no-source-map --quiet-deps
                                                     --silence-deprecation=import --silence-deprecation=color-functions
                                                     --silence-deprecation=global-builtin
                                                     --load-path=vendor/stylesheets/bootstrap]
