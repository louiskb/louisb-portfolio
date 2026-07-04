# Public sign-up is permanently closed on this single-owner site: the one
# account is created by db:seed (or the Rails console), never through the web.
#
# Why a controller guard and not just the model validation: the User model's
# one_account_allowed rule only blocks a SECOND row at save time. On a fresh,
# unseeded database (a staging clone, a review app, a restored backup, or the
# gap between first migrate and first seed) the users table is empty — without
# this guard, the first anonymous visitor to reach /users/sign_up would
# register themselves as the permanent owner and lock Louis out.
#
# Only :new and :create are overridden. Account editing (registrations#edit /
# #update) stays available to the signed-in owner via the profile page.
class Users::RegistrationsController < Devise::RegistrationsController
  def new
    redirect_to new_user_session_path, alert: "Sign-up is disabled on this site."
  end

  def create
    redirect_to new_user_session_path, alert: "Sign-up is disabled on this site."
  end
end
