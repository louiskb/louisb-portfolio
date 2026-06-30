class BackfillTagsAndDropLegacyColumn < ActiveRecord::Migration[8.1]
  # Legacy `blog_posts.tags` stored a single string with tags separated by the
  # literal " . " (dot-space) sequence — e.g. "Rails 7 . ActionMailer . Heroku".
  # We split on that exact separator (NOT comma/space) so multiword tags like
  # "Contact Form" survive intact, then move each tag into the tags / join
  # tables before dropping the legacy column.
  SEPARATOR = " . "

  # Lightweight, validation-free models scoped to this migration so the backfill
  # is decoupled from the app models (which may change later).
  class MigrationBlogPost < ActiveRecord::Base
    self.table_name = "blog_posts"
  end

  class MigrationTag < ActiveRecord::Base
    self.table_name = "tags"
  end

  class MigrationBlogPostTag < ActiveRecord::Base
    self.table_name = "blog_post_tags"
  end

  def up
    now = Time.current

    MigrationBlogPost.find_each do |post|
      next if post.tags.blank?

      post.tags.split(SEPARATOR).each do |raw|
        name = normalize(raw)
        next if name.blank?

        tag = MigrationTag.where("LOWER(name) = ?", name.downcase).first ||
              MigrationTag.create!(name: name, created_at: now, updated_at: now)

        unless MigrationBlogPostTag.exists?(blog_post_id: post.id, tag_id: tag.id)
          MigrationBlogPostTag.create!(
            blog_post_id: post.id, tag_id: tag.id, created_at: now, updated_at: now
          )
        end
      end
    end

    remove_column :blog_posts, :tags, :string
  end

  def down
    # Schema-reversible only: this restores an EMPTY tags column. The original
    # strings now live in the tags / blog_post_tags tables, not this column.
    add_column :blog_posts, :tags, :string
  end

  # Capitalise the first letter of each word, preserving hyphens — identical to
  # the Tag model's before_save so future find_or_create_by calls match.
  def normalize(raw)
    raw.to_s.strip.gsub(/\b[a-z]/) { |m| m.upcase }
  end
end
