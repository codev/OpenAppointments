# Be sure to restart your server when you modify this file.

Rails.application.config.assets.version = "1.0"

# EA frontend assets: ported JS under app/javascript (served verbatim, no bundling),
# vendored third-party dist files under vendor/assets/vendor.
Rails.application.config.assets.paths << Rails.root.join("app/javascript")
Rails.application.config.assets.paths << Rails.root.join("vendor/assets")
