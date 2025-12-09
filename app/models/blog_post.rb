class BlogPost < ApplicationRecord
  # Associations
  belongs_to :user # creates a method `blog_post.users` that shows who the owner / creator of the blog_post is.

  # Validations
  validates :title, presence: true
  validates :description, presence: true
  validates :img_url, presence: true
  validates :tags, presence: true
  validates :html_content, presence: true
  validates :user_id, presence: true
end
