# The waiting list: a freed slot is offered to the matching signups straight
# away, longest waiting first and a stagger apart so the first has a head
# start; the daily scan tells signups whose service has enough free hours in
# the booking window, once a day. Notices go through WaitlistNoticeJob, which
# checks the signup and the slot again when its turn comes.
module Waitlist
  module_function

  def enabled? = Setting.get("waitlist_enabled") == "1" && Messaging.enabled?
  def stagger = Setting.get("waitlist_stagger_seconds", "60").to_i.seconds
  def min_slots = Setting.get("waitlist_min_slots", "3").to_i

  # A cancelled or deleted appointment.
  def slot_freed(appointment)
    return unless enabled? && appointment&.provider && appointment.start_datetime && !BookingWindows.past?(appointment)

    minutes = ((appointment.end_datetime - appointment.start_datetime) / 60).to_i
    slot = { "provider_id" => appointment.provider.id, "start" => appointment.start_datetime.strftime("%Y-%m-%d %H:%M:%S"),
             "minutes" => minutes }
    schedule(WaitlistEntry.for_freed_slot(appointment.provider, minutes), "slot_freed", slot)
  end

  def scan_daily(now = Time.current)
    return unless enabled?

    due = WaitlistEntry.live(now).oldest_first
                       .where("last_digest_at IS NULL OR last_digest_at < ?", now.beginning_of_day)
                       .select { |entry| free_slots(entry) >= min_slots }
    schedule(due, "daily")
  end

  # Free hours in the whole booking window for the signup's service and provider.
  def free_slots(entry)
    BookingWindow.build(entry.service, entry.provider_id || BookingPayloads::ANY_PROVIDER).values.sum(&:size)
  end

  def schedule(entries, kind, slot = nil)
    entries.each_with_index do |entry, index|
      job = index.zero? ? WaitlistNoticeJob : WaitlistNoticeJob.set(wait: index * stagger)
      job.perform_later(entry.id, kind, slot)
    end
  end

  # The job's turn: send unless the signup went, expired, is capped or the
  # slot has been taken since.
  def notify(entry, kind, slot)
    return if entry.nil? || entry.expired?

    if kind == "slot_freed"
      return unless entry.notices_left?

      provider = User.providers.find_by(id: slot["provider_id"])
      start_at = Time.parse(slot["start"])
      return unless provider && slot_free?(entry, provider, start_at)

      Notifications.waitlist_notice(:waitlist_slot_freed, entry,
                                    Messaging::Template.waitlist_context(entry: entry, provider: provider, start_at: start_at))
      entry.increment!(:notices_sent)
    else
      Notifications.waitlist_notice(:waitlist_daily, entry,
                                    Messaging::Template.waitlist_context(entry: entry, provider: entry.provider))
      entry.update!(last_digest_at: Time.current)
    end
  end

  def slot_free?(entry, provider, start_at)
    hours = Availability::Engine.new.available_hours(start_at.strftime("%Y-%m-%d"), entry.service, provider)
    hours.include?(start_at.strftime("%H:%M"))
  end
end
