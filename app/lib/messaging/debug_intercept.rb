module Messaging
  # ActionMailer interceptor for Debug on Messages > Settings: every email goes
  # to the intercept address with the real recipient marked on top of each text
  # part. Mail already addressed to the intercept (Message rows redirected by
  # MessageDeliveryJob) passes through untouched.
  module DebugIntercept
    module_function

    def delivering_email(mail)
      return unless Messaging.debug?

      intercept = Messaging.intercept_address("email")
      return if intercept.nil? || mail.to == [ intercept ]

      original = Array(mail.to).join(", ")
      mail.to = intercept
      mail.cc = nil
      mail.bcc = nil
      parts = mail.multipart? ? mail.all_parts : [ mail ]
      parts.each do |part|
        next unless part.mime_type.to_s.start_with?("text/")

        part.body = Messaging.mark_original_to(part.body.decoded, original)
      end
    end
  end
end
