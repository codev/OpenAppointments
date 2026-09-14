# Debug on Messages > Settings redirects every outgoing email (see Messaging::DebugIntercept).
Rails.application.config.to_prepare do
  ActionMailer::Base.register_interceptor(Messaging::DebugIntercept)
end
