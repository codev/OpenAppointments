# GDPR consent log, ported from EA's consents table.
class Consent < ApplicationRecord
  self.inheritance_column = nil # `type` is a consent kind ("book", "delete"), not STI

  validates :type, presence: true
end
