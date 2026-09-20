# How dates are written on pages and in messages: the date_display setting
# picks a style, the date_format setting the order. Names come from the
# current locale (rails-i18n), English when the locale has none. Date fields
# keep the numeric format so typed values parse.
module DateDisplay
  module_function

  STYLES = %w[numeric month_short month_long day_short day_long].freeze

  PATTERNS = {
    "DMY" => { "month_short" => "%-d %b %Y", "month_long" => "%-d %B %Y",
               "day_short" => "%a %-d %b %Y", "day_long" => "%A %-d %B %Y" },
    "MDY" => { "month_short" => "%b %-d, %Y", "month_long" => "%B %-d, %Y",
               "day_short" => "%a, %b %-d, %Y", "day_long" => "%A, %B %-d, %Y" },
    "YMD" => { "month_short" => "%Y %b %-d", "month_long" => "%Y %B %-d",
               "day_short" => "%Y %b %-d, %a", "day_long" => "%Y %B %-d, %A" }
  }.freeze

  def style = Setting.get("date_display", "numeric")

  def format(date, style: self.style, date_format: Setting.get("date_format"))
    date_format = "DMY" unless PATTERNS.key?(date_format)
    pattern = PATTERNS[date_format][style]
    return date.strftime(MailerFormatHelper::DATE_FORMATS[date_format]) unless pattern

    I18n.l(date.to_date, format: pattern, locale: names_locale)
  end

  def format_time(time, style: self.style)
    time_format = MailerFormatHelper::TIME_FORMATS[Setting.get("time_format")] || MailerFormatHelper::TIME_FORMATS["regular"]
    "#{format(time, style: style)} #{time.strftime(time_format).strip}"
  end

  def names_locale
    I18n.exists?("date.day_names", I18n.locale) ? I18n.locale : :en
  end
end
