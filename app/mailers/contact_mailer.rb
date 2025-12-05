class ContactMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.contact_mailer.received_email.subject
  #
  def received_email
    @contact = params[:contact]
    mail(
      to: ENV["MAILER_SENDER"],
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
      from: ENV["MAILER_SENDER"],
      subject: "Message received!"
    )
  end
end
