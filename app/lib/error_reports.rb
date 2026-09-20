# Who receives crash report emails: the comma separated EXCEPTION_RECIPIENTS
# environment variable, set per instance (see RELEASING.md).
module ErrorReports
  module_function

  def recipients
    ENV["EXCEPTION_RECIPIENTS"].to_s.split(",").map(&:strip).reject(&:blank?)
  end

  # Without recipients no report is attempted, so an unset variable stays quiet
  # instead of logging a blank address error on every crash.
  def enabled?
    recipients.any?
  end
end
