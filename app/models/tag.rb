class Tag < ApplicationRecord
  has_many :blog_post_tags, dependent: :destroy
  has_many :blog_posts, through: :blog_post_tags

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # Capitalise the first letter of each word, preserving hyphens.
  # titleize strips hyphens ("Transit-Oriented" → "Transit Oriented"), so use \b instead.
  before_save { self.name = name.strip.gsub(/\b[a-z]/) { |m| m.upcase } }
end
