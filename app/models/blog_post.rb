class BlogPost < ApplicationRecord
  include Publishable

  extend FriendlyId
  friendly_id :title, use: :slugged

  # Associations
  belongs_to :user # creates a method `blog_post.users` that shows who the owner / creator of the blog_post is.

  # Uploaded media (Cloudinary in production, Disk in dev/test). Variant
  # processing is disabled — originals are rendered directly.
  has_one_attached :featured_image
  has_many_attached :photos

  # Rich text body (Action Text / Trix) for new manual posts. AI/legacy posts
  # use the raw html_content column instead — never both (see one_content_field_only).
  has_rich_text :body

  # Validations
  validates :title, presence: true
  validates :description, presence: true
  validates :img_url, presence: true
  validates :tags, presence: true
  validates :html_content, presence: true
  validates :user_id, presence: true
end
