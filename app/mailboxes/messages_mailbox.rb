# Turns fetched inbound email into incoming Message rows. Sender is matched to
# a customer by email; unmatched mail lands in the Unknown Inbox (customer nil).
class MessagesMailbox < ApplicationMailbox
  def process
    from = mail.from&.first.to_s
    customer = User.customers.where("LOWER(email) = ?", from.downcase).first if from.present?

    Message.create!(
      direction: "incoming", channel: "email", status: "received",
      from_address: from, to_address: mail.to&.first,
      customer_id: customer&.id, subject: mail.subject, body: body_text
    )
  end

  private

  def body_text
    part = mail.multipart? ? (mail.text_part || mail.html_part) : mail
    text = part&.decoded.to_s
    part == mail.html_part ? ActionController::Base.helpers.strip_tags(text) : text
  rescue StandardError
    ""
  end
end
