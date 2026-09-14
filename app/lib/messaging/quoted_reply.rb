module Messaging
  # The new text of a reply email: quoted lines and everything from the point
  # where a mail client starts quoting the earlier mail are dropped. The full
  # text stays on Message#source.
  module QuotedReply
    # Gmail and Apple Mail introduce the quote with "On <date>, <name> wrote:",
    # sometimes wrapped over two lines.
    ON_WROTE = /\AOn\b[^\n]{0,200}(\n[^\n]{0,200})?wrote:\s*\z/
    ORIGINAL_MESSAGE = /\A-{2,}\s*Original Message\s*-{2,}\z/i
    OUTLOOK_RULE = /\A_{5,}\s*\z/
    SIGNATURE = /\A--\s*\z/
    # Outlook without a rule: a From: line followed within a few lines by Sent: or Date:.
    MAIL_HEADER = /\A(From|Sent|Date|To|Subject):\s/

    module_function

    def strip(text)
      lines = text.to_s.gsub("\r\n", "\n").split("\n", -1)
      cut = lines.each_index.find { |index| quote_starts_at?(lines, index) }
      kept = (cut ? lines.first(cut) : lines).reject { |line| line.start_with?(">") }
      result = kept.join("\n").strip
      result.empty? ? text.to_s.strip : result
    end

    def quote_starts_at?(lines, index)
      line = lines[index]
      return true if line.match?(ORIGINAL_MESSAGE) || line.match?(OUTLOOK_RULE) || line.match?(SIGNATURE)
      return true if line.match?(ON_WROTE) || "#{line}\n#{lines[index + 1]}".match?(ON_WROTE)

      line.start_with?("From:") && lines[index + 1, 3].to_a.any? { |next_line| next_line.match?(/\A(Sent|Date):\s/) }
    end
  end
end
