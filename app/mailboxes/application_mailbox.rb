class ApplicationMailbox < ActionMailbox::Base
  routing all: :messages
end
