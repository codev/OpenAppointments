require "test_helper"

class TerminologyTest < ActiveSupport::TestCase
  setup do
    Setting.set("provider_label", "Stylist")
    Setting.set("provider_label_plural", "Stylists")
  end

  test "rewrites provider words preserving case" do
    assert_equal "Select Stylist", Terminology.apply("select_provider", "Select Provider")
    assert_equal "Stylists", Terminology.apply("providers", "Providers")
    assert_equal "Select a stylist or a service", Terminology.apply("hint", "Select a provider or a service")
  end

  test "service words are left alone when no label is set" do
    assert_equal "Service", Terminology.apply("service", "Service")
    Setting.set("service_label", "Treatment")
    assert_equal "Treatment", Terminology.apply("service", "Service")
  end

  test "skips keys where the word means something else" do
    assert_equal "Captcha provider", Terminology.apply("captcha_provider", "Captcha provider")
    assert_equal "Providers", Terminology.apply("messages_providers", "Providers")
    assert_equal "Provider (singular)", Terminology.apply("provider_label", "Provider (singular)")
  end

  test "only applies to English" do
    assert_equal "Provider", Terminology.apply("provider", "Provider", Terminology.labels, :de)
    assert_equal({ "provider" => "Provider" }, Terminology.apply_all({ "provider" => "Provider" }, "de"))
    assert_equal({ "provider" => "Stylist" }, Terminology.apply_all({ "provider" => "Provider" }, "en"))
  end

  test "blank labels disable the rewrite" do
    Setting.set("provider_label", " ")
    Setting.set("provider_label_plural", "")
    assert_equal "Provider", Terminology.apply("provider", "Provider")
  end

  test "window.lang payload and lang helper use the labels" do
    assert_equal "Stylist", Localization.translations("english")["provider"]
    assert_equal "Anbieter", Localization.translations("german")["provider"]
  end
end
