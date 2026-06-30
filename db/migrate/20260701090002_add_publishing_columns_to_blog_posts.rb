class AddPublishingColumnsToBlogPosts < ActiveRecord::Migration[8.1]
  def up
    add_column :blog_posts, :slug, :string
    add_column :blog_posts, :status, :integer, default: 2, null: false
    add_column :blog_posts, :scheduled_at, :datetime
    add_column :blog_posts, :featured, :boolean, default: false
    add_column :blog_posts, :blog_excerpt, :text
    add_column :blog_posts, :featured_image_caption, :text
    add_column :blog_posts, :ai_generated, :boolean, default: false
    add_column :blog_posts, :human_generated, :boolean, default: false, null: false
    add_column :blog_posts, :author, :string
    # position is not in the original spec for blog_posts, but the drag-to-reorder
    # action (Task 1.5) writes `position` for both models, so the column is required.
    add_column :blog_posts, :position, :integer

    add_index :blog_posts, :slug, unique: true

    execute <<~SQL.squish
      UPDATE blog_posts
      SET position = sub.rn - 1
      FROM (
        SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS rn
        FROM blog_posts
      ) sub
      WHERE blog_posts.id = sub.id
    SQL
  end

  def down
    remove_index :blog_posts, :slug
    remove_column :blog_posts, :position
    remove_column :blog_posts, :author
    remove_column :blog_posts, :human_generated
    remove_column :blog_posts, :ai_generated
    remove_column :blog_posts, :featured_image_caption
    remove_column :blog_posts, :blog_excerpt
    remove_column :blog_posts, :featured
    remove_column :blog_posts, :scheduled_at
    remove_column :blog_posts, :status
    remove_column :blog_posts, :slug
  end
end
