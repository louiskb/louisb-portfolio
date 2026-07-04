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
  validate :featured_image_is_a_reasonable_image

  # Same upload hygiene rules as BlogPost (see the comment there).
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_IMAGE_BYTES = 10.megabytes

  private

  def featured_image_is_a_reasonable_image
    return unless featured_image.attached?

    unless featured_image.content_type.in?(ALLOWED_IMAGE_TYPES)
      errors.add(:featured_image, "must be a PNG, JPEG, GIF, or WebP image")
    end
    if featured_image.blob.byte_size > MAX_IMAGE_BYTES
      errors.add(:featured_image, "must be smaller than 10 MB")
    end
  end
end
