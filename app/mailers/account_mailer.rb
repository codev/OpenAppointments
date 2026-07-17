# Account emails. Plain placeholders until P6 ports the EA HTML templates.
class AccountMailer < ApplicationMailer
  def password_reset_link(email, reset_link)
    @reset_link = reset_link
    mail(to: email, subject: "Password Reset - #{Setting.get('company_name')}")
  end
end
