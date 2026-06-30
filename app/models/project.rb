class Project < ApplicationRecord
  include Publishable

  extend FriendlyId
  friendly_id :title, use: :slugged

  # Associations
  belongs_to :user

  # Uploaded media (Cloudinary in production, Disk in dev/test). Variant
  # processing is disabled — originals are rendered directly.
  has_one_attached :featured_image

  # Validations
  validates :title, presence: true
  validates :description, presence: true
  validates :img_url, presence: true
  validates :tech_stack, presence: true
  validates :project_url, presence: true
  validates :user_id, presence: true
end
