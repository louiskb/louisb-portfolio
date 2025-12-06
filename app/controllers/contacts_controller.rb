class ContactsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :create ]
  invisible_captcha only: [:create]
  
  def new
    @contact = Contact.new
  end

  def create
    @contact = Contact.new(contact_params)

    if @contact.save
      # flash[:notice] = "Contact saved! ID: #{@contact.id}"  # ← Debug

      ContactMailer.with(contact: @contact).received_email.deliver_now

      # flash[:notice] += " | Received email sent"  # ← Debug

      ContactMailer.with(contact: @contact).confirmation_email.deliver_now

      # flash[:notice] += " | Confirmation sent"    # ← Debug

      redirect_to root_path(anchor: "contact"), notice: "Message sent! Check your email for confirmation."
    else
      # redirect_to root_path, alert: "Message failed to send!" - this line of code works the same as the two lines below for your reference.
      flash[:alert] = "Message failed to send!"
      redirect_to root_path(anchor: "contact")
      # render :new, status: :unprocessable_entity vs redirect_to root_path explained -> #render method accepts routes that are connected up with the same controller actions, models, and routes. status: :unprocessable_entity (422) is a non-redirect status code which conflicts with the 302 redirect code (and hence the #redirect_to method). If using `notices` or `alerts` with #render method, browsers often ignore flash messages on non-redirect status codes like 422.
      # When using render (not redirect), flash messages need flash.now[:alert] instead of flash[:alert] because render doesn't trigger a new request. Regular flash[:alert] only persists across redirects.
      # FYI `notice` gives a green flash notification.
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:first_name, :last_name, :email, :message)
  end
end
