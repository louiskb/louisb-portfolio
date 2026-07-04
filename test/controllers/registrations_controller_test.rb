require "test_helper"

# Public sign-up is permanently disabled (Users::RegistrationsController):
# the single owner account only ever comes from db:seed / the console. These
# tests pin that behaviour, including the scenario that motivated it — an
# EMPTY users table, where the model's one_account_allowed validation alone
# would happily let the first anonymous visitor become the owner.
class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "sign-up page redirects to sign-in" do
    get new_user_registration_url
    assert_redirected_to new_user_session_url
  end

  test "sign-up POST never creates an account" do
    assert_no_difference "User.count" do
      post user_registration_url, params: { user: {
        email: "attacker@example.com",
        password: "password123",
        password_confirmation: "password123"
      } }
    end
    assert_redirected_to new_user_session_url
  end

  test "sign-up stays blocked on an empty users table (the takeover scenario)" do
    # Simulate a fresh/unseeded database (review app, staging clone, restored
    # backup). Dependents go first to satisfy foreign keys.
    BlogPostTag.delete_all
    BlogPost.delete_all
    Project.delete_all
    User.delete_all

    post user_registration_url, params: { user: {
      email: "attacker@example.com",
      password: "password123",
      password_confirmation: "password123"
    } }

    assert_redirected_to new_user_session_url
    assert_equal 0, User.count, "an unseeded database must not be claimable via sign-up"
  end
end
