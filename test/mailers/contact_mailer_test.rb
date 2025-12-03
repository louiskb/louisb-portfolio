require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  test "received_email" do
    mail = ContactMailer.received_email
    assert_equal "Received email", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "confirmation_email" do
    mail = ContactMailer.confirmation_email
    assert_equal "Confirmation email", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
