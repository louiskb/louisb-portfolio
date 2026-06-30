class BlogPost < ApplicationRecord
  include Publishable

  extend FriendlyId
  friendly_id :title, use: :slugged

  # Associations
  belongs_to :user # creates a method `blog_post.users` that shows who the owner / creator of the blog_post is.

  has_many :blog_post_tags, dependent: :destroy
  has_many :tags, through: :blog_post_tags

  # Uploaded media (Cloudinary in production, Disk in dev/test). Variant
  # processing is disabled — originals are rendered directly.
  has_one_attached :featured_image
  has_many_attached :photos

  # Rich text body (Action Text / Trix) for new manual posts. AI/legacy posts
  # use the raw html_content column instead — never both (see one_content_field_only).
  has_rich_text :body

  before_validation :set_author

  # Validations
  # A post renders EITHER the Action Text `body` (manual) OR `html_content`
  # (AI / legacy raw HTML), never both — so we don't require either to be
  # present (drafts and AI posts with rescued img_url stay valid).
  validates :title, presence: true
  validates :status, presence: true
  validate :one_content_field_only

  # Returns estimated reading time as a string, e.g. "4 min read".
  # Strips HTML tags, counts words, assumes 200 wpm. Minimum 1 min.
  def reading_time
    text = if html_content.present?
      ActionController::Base.helpers.strip_tags(html_content)
    elsif body.present?
      body.to_plain_text
    else
      ""
    end
    words = text.split.size
    minutes = [(words / 200.0).ceil, 1].max
    "#{minutes} min read"
  end

  # Up to 3 recent published posts that share at least one tag with this post.
  # Returns an empty relation when this post has no tags.
  def related_posts
    return BlogPost.none if tag_ids.empty?

    BlogPost.published
            .joins(:tags)
            .where(tags: { id: tag_ids })
            .where.not(id: id)
            .distinct
            .order(created_at: :desc)
            .limit(3)
  end

  # Returns a display label for AI involvement, shown to Louis only.
  # nil when no AI was involved (pure manual, or manual with no AI revision).
  def ai_label
    return "Revised with AI" if ai_generated? && human_generated?
    return "Created with AI" if ai_generated?
    nil
  end

  private

  def set_author
    self.author = "Louis Bourne"
  end

  # A post may carry rich text content OR raw HTML content, but never both.
  # An empty Trix submission deserialises to a blank ActionText::Content, so
  # `body.present?` already returns false for it — no special-casing needed.
  def one_content_field_only
    if html_content.present? && body.present?
      errors.add(:base, "A post can only have rich text content or HTML content, not both.")
    end
  end
end
