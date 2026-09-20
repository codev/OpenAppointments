# One waiting list notice, queued by Waitlist with a growing delay per signup.
class WaitlistNoticeJob < ApplicationJob
  def perform(entry_id, kind, slot = nil)
    Waitlist.notify(WaitlistEntry.find_by(id: entry_id), kind, slot)
  end
end
