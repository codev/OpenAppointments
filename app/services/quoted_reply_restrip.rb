# One-off: email replies received before quote stripping existed hold the
# quote in the body and have no source. Strips them, keeping the original in
# source; rows with a source are already done, so re-runs change nothing.
module QuotedReplyRestrip
  module_function

  # Returns how many messages were (or, on a dry run, would be) changed.
  def run(dry_run: false)
    count = 0
    Message.incoming.where(channel: "email", source: nil).find_each do |message|
      stripped = Messaging::QuotedReply.strip(message.body)
      next if stripped == message.body

      count += 1
      message.update!(source: message.body, body: stripped) unless dry_run
    end
    count
  end
end
