# Activity page: a badge colour per kind, and the summary and details with their
# template's own words (for, with, to, by, Status, Reason) set apart so the
# names, times and addresses stand out.
module ActivityHelper
  BADGE_CLASSES = {
    "appointment_booked" => "text-bg-success",
    "appointment_changed" => "text-bg-primary",
    "appointment_cancelled" => "text-bg-warning",
    "appointment_deleted" => "text-bg-danger",
    "unavailability_saved" => "text-bg-secondary",
    "unavailability_deleted" => "bg-secondary-subtle text-secondary-emphasis border",
    "message_sent" => "text-bg-info",
    "message_failed" => "bg-danger-subtle text-danger-emphasis border",
    "message_received" => "bg-primary-subtle text-primary-emphasis border",
    "waitlist_signup" => "bg-success-subtle text-success-emphasis border",
    "reminders_marked" => "text-bg-dark"
  }.freeze

  # The locale templates each kind's summary was built from, in Activity.
  SUMMARY_TEMPLATES = {
    "appointment_booked" => %w[activity_appointment_summary],
    "appointment_changed" => %w[activity_appointment_summary],
    "appointment_cancelled" => %w[activity_appointment_summary],
    "appointment_deleted" => %w[activity_appointment_summary],
    "message_sent" => %w[activity_message_summary],
    "message_failed" => %w[activity_message_summary],
    "message_received" => %w[activity_received_summary],
    "waitlist_signup" => %w[activity_waitlist_summary]
  }.freeze

  def activity_badge_class(kind)
    BADGE_CLASSES.fetch(kind, "text-bg-secondary")
  end

  def activity_summary_html(event)
    activity_styled(event.summary, SUMMARY_TEMPLATES.fetch(event.kind, []).map { |key| I18n.t("ea.#{key}") })
  end

  # Appointment details are the status, the reason, or both joined by ". ".
  def activity_details_html(event)
    return activity_styled(event.details, []) unless event.kind.start_with?("appointment_")

    status = I18n.t("ea.activity_status_summary")
    reason = I18n.t("ea.activity_reason_summary")
    activity_styled(event.details, [ "#{status}. #{reason}", status, reason ])
  end

  # The text with the literal words of the first template whose shape it
  # matches in <i>; text from no template, or from an older wording, stays plain.
  def activity_styled(text, templates)
    text = text.to_s
    templates.each do |template|
      words = template.split(/\{\{\w+\}\}/, -1)
      pattern = Regexp.new("\\A#{words.map { |word| Regexp.escape(word) }.join('(.*?)')}\\z", Regexp::MULTILINE)
      match = text.match(pattern)
      next unless match

      return safe_join(words.each_with_index.map { |word, i| [ activity_joiner(word), match.captures[i] ].compact })
    end
    ERB::Util.html_escape(text)
  end

  private

  # A template word in <i>, the punctuation and spaces before it and the
  # spaces after it kept outside; punctuation alone stays as it is.
  def activity_joiner(word)
    lead, core, tail = word.match(/\A([^\p{L}]*)(.*?)(\s*)\z/m).captures
    return word unless core.match?(/\p{L}/)

    safe_join([ lead, tag.i(core, class: "activity-joiner"), tail ])
  end
end
