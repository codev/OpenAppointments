require "test_helper"

class ThemesTest < ActionDispatch::IntegrationTest
  THEMES = %w[brutalism coder fruit material nice outline solid].freeze

  test "the seven themes are whitelisted and built" do
    assert_equal THEMES, BookingController::THEMES.sort
    builds = Rails.application.config.dartsass.builds
    THEMES.each do |theme|
      assert_equal "themes/#{theme}.css", builds["ea/themes/#{theme}.scss"], "missing build for #{theme}"
      assert Rails.root.join("app/assets/builds/themes/#{theme}.css").exist?, "missing css for #{theme}"
    end
  end

  test "the booking page accepts each theme and falls back to nice" do
    THEMES.each do |theme|
      get "/", params: { theme: theme }
      assert_response :success
      assert_match %r{themes/#{theme}}, response.body
    end

    get "/", params: { theme: "cosmo" }
    assert_match %r{themes/nice}, response.body
  end

  test "seeds default the theme to nice" do
    assert_match(/"theme" => "nice"/, Rails.root.join("db/seeds.rb").read)
  end

  test "the theme migration converts retired themes to nice" do
    migration = Rails.root.glob("db/migrate/*_migrate_theme_to_nice.rb").first
    require migration
    Setting.set("theme", "darkly")
    ActiveRecord::Migration.suppress_messages { MigrateThemeToNice.new.up }
    assert_equal "nice", Setting.get("theme")

    Setting.set("theme", "brutalism")
    ActiveRecord::Migration.suppress_messages { MigrateThemeToNice.new.up }
    assert_equal "brutalism", Setting.get("theme")
  end

  test "every theme consumes the brand variables and avoids remote fonts" do
    THEMES.each do |theme|
      source = Rails.root.join("app/assets/stylesheets/ea/themes/#{theme}.scss").read
      assert_match(/@import 'bootstrap'/, source)
      assert_match(/@import 'shared'/, source)
      css = Rails.root.join("app/assets/builds/themes/#{theme}.css").read
      assert_no_match(/fonts\.googleapis|@import url/, css, "#{theme} pulls remote fonts")
      assert_match(/--oa-primary/, css)
    end
  end

  test "outline styling keeps its outline character" do
    source = Rails.root.join("app/assets/stylesheets/ea/themes/outline.scss").read
    assert_match(/button-outline-variant/, source)
  end
end
