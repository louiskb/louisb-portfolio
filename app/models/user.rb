class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :projects # creates a method `user.projects`, that shows all the `projects` the `user` owns / created.
  has_many :blog_posts # creates a method `user.blog_posts`, that shows ll the `blog_posts` the `user` owns / created

  # Validations
  # Use `validate` (single) with a custom method (symbol) for your own validation logic. You pass the name of a method (symbol) that will be called to perform validations manually.
  # Use `validates` (plural) with built-in validation helpers on attributes (columns in the table). It takes attribute names plus validation options.
  validate :one_account_allowed, on: :create # `on:` specifies when the validation only runs when creating a new record, not when updating an existing one. If omitted, validations run on both `create and `update` by default.

  private

  def one_account_allowed
    if User.exists?
      errors.add(:base, "Only one user account is allowed.") # `:base` is used when adding an error to the entire object (error on whole model) rather than to a specific attribute.
    end
  end
end
