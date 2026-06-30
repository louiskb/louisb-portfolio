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
  # Only the title is required: a draft project may be created before every
  # field is filled, and existing rows already have the rest. `status` comes
  # from the Publishable concern; `user` is enforced by `belongs_to`.
  validates :title, presence: true
end
