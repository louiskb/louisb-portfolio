class ContactMailer < ApplicationMailer

  # What is a Rails mailer class ?
  # Mailer classes generated with the BASH command eg. `rails generate mailer ContactMailer received_email confirmation_email`, generates a new Rails mailer class in this case called `ContactMailer` and starter templates for two email actions.
  # Mailer classes generated with this command eg. `rails generate mailer ContactMailer` (ie. contact_mailer.rb / ContactMailer class) defines (1) what emails are sent (the mailer actions (methods)), (2) to whom and what subject (headers of the email eg. to, from, subject, reply_to), and (3) content (matching views that define the content, look, and structure of the email sent) for your contact form.

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
