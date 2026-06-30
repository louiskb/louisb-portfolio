require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  test "new requires authentication" do
    get new_contact_url
    assert_redirected_to new_user_session_url
  end

  test "new succeeds when signed in" do
    sign_in users(:louis)
    get new_contact_url
    assert_response :success
  end

  test "create saves a contact and redirects (public)" do
    assert_difference "Contact.count", 1 do
      post contacts_url, params: { contact: {
        first_name: "Sam",
        last_name: "Visitor",
        email: "sam@example.com",
        message: "Hi Louis, great portfolio!"
      } }
    end
    assert_response :redirect
  end

  test "create rejects invalid params" do
    assert_no_difference "Contact.count" do
      post contacts_url, params: { contact: {
        first_name: "", last_name: "", email: "nope", message: ""
      } }
    end
    assert_response :redirect
  end
end
