# Preview all emails at http://localhost:3000/rails/mailers/contact_mailer
class ContactMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/contact_mailer/received_email
  def received_email
    ContactMailer.received_email
  end

  # Preview this email at http://localhost:3000/rails/mailers/contact_mailer/confirmation_email
  def confirmation_email
    ContactMailer.confirmation_email
  end

end
