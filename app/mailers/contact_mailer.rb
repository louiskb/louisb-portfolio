class ContactMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.contact_mailer.received_email.subject
  #
  def received_email
    @contact = params[:contact]
    mail(
      to: "dev@louisbourne.me",
      subject: "New Contact: #{@contact.first_name} #{@contact.last_name}",
      reply_to: @contact.email
    )
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.contact_mailer.confirmation_email.subject
  #
  def confirmation_email
    @contact = params[:contact]
    mail(
      to: @contact.email,
      from: "dev@louisbourne.me",
      subject: "Thank you for your message!"
    )
  end
end
