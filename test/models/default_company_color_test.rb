require "test_helper"

class DefaultCompanyColorTest < ActiveSupport::TestCase
  MIGRATION = Rails.root.glob("db/migrate/*_default_company_color.rb").first

  test "migration turns the old white sentinel into the new default green" do
    require MIGRATION
    Setting.set("company_color", "#ffffff")
    ActiveRecord::Migration.suppress_messages { DefaultCompanyColor.new.up }
    assert_equal "#39824f", Setting.get("company_color")
  end

  test "migration leaves a custom colour alone" do
    require MIGRATION
    Setting.set("company_color", "#123456")
    ActiveRecord::Migration.suppress_messages { DefaultCompanyColor.new.up }
    assert_equal "#123456", Setting.get("company_color")
  end

  test "seeds default the company colour to green" do
    assert_match(/"company_color" => "#39824f"/, Rails.root.join("db/seeds.rb").read)
  end

  test "white stays the unset sentinel for the colour style block" do
    assert_equal "#ffffff", CompanyColorHelper::DEFAULT_COMPANY_COLOR
  end
end
