# EA date_helper.php equivalents for mailer views (application/helpers/date_helper.php).
module MailerFormatHelper
  # EA get_date_format: DMY -> d/m/Y, MDY -> m/d/Y, YMD -> Y/m/d.
  DATE_FORMATS = { "DMY" => "%d/%m/%Y", "MDY" => "%m/%d/%Y", "YMD" => "%Y/%m/%d" }.freeze
  # EA get_time_format: regular -> g:i a, military -> H:i.
  TIME_FORMATS = { "regular" => "%-l:%M %P", "military" => "%H:%M" }.freeze

  # EA format_date_time: value formatted per the date_format + time_format settings.
  def format_appointment_datetime(time, settings)
    date_format = DATE_FORMATS[settings[:date_format]] || DATE_FORMATS["DMY"]
    time_format = TIME_FORMATS[settings[:time_format]] || TIME_FORMATS["regular"]
    time.strftime("#{date_format} #{time_format}").strip
  end

  # EA format_timezone: identifier -> display label (Timezones::get_timezone_name).
  def format_timezone(value)
    return if value.blank?

    timezones[value] || value
  end

  # EA nl2br(e(...)).
  def nl2br(text)
    safe_join(text.to_s.split("\n", -1), tag(:br))
  end
end
