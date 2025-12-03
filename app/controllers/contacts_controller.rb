class ContactsController < ApplicationController
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)

    if @contact.save
      ContactMailer.with(contact: @contact).received_email.deliver_later
      ContactMailer.with(contact: @contact).confirmation_email.deliver_later
      redirect_to contact_path, notice: "Message sent! Check your email for confirmation."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:first_name, :last_name, :email, :message)
  end
end
