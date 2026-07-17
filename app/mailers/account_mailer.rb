# Account emails (EA Email_messages::send_password_reset_link / send_password).
class AccountMailer < ApplicationMailer
  def password_reset_link(email, reset_link)
    @reset_link = reset_link
    @subject = I18n.t("ea.reset_password")
    mail(to: email, from: company_from, reply_to: company_reply_to,
         subject: "#{@subject} - #{Setting.get('company_name')}")
  end
end
