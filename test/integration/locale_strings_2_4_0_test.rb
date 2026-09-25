require "test_helper"

# Every locale carries the 2.4.0 strings, with the placeholders the code fills in.
class LocaleStrings240Test < ActiveSupport::TestCase
  PLACEHOLDERS = {
    "notification_unknown_tokens" => "{tokens}", "token_copied" => "{token}",
    "inbox_done_by" => "{name}", "message_move_to" => "{name}"
  }.freeze
  KEYS = %w[notification_unsaved notification_unknown_tokens notification_has_unknown_tokens token_copied
            inbox_done inbox_show_done inbox_done_by message_delete_confirm message_deleted
            message_shared_contact message_move_to message_moved notification_tokens_hint
            inbox_info unknown_inbox_info booking_release_time booking_release_time_hint].freeze

  test "the 2.4.0 strings exist in every locale with their placeholders" do
    I18n.available_locales.each do |locale|
      KEYS.each do |key|
        value = I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil)
        assert value.present?, "missing ea.#{key} in #{locale}"
        assert_includes value, PLACEHOLDERS[key], "#{locale} ea.#{key}" if PLACEHOLDERS[key]
      end
      assert_includes I18n.t("ea.inbox_done_by", locale: locale), "{time}", "#{locale} ea.inbox_done_by"
    end
  end

  test "re-worded keys are no longer the old English outside en" do
    (I18n.available_locales - [ :en ]).each do |locale|
      assert_not_equal "Template fields you can use:", I18n.t("ea.notification_tokens_hint", locale: locale), locale.to_s
    end
  end
end
