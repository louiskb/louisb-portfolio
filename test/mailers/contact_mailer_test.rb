require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  setup { @contact = contacts(:jane) }

  test "received_email subject names the sender and replies to them" do
    mail = ContactMailer.with(contact: @contact).received_email
    assert_equal "New Contact: #{@contact.first_name} #{@contact.last_name}", mail.subject
    assert_equal [@contact.email], mail.reply_to
  end

  test "confirmation_email is addressed to the sender" do
    mail = ContactMailer.with(contact: @contact).confirmation_email
    assert_equal "Message received!", mail.subject
    assert_equal [@contact.email], mail.to
  end
end
