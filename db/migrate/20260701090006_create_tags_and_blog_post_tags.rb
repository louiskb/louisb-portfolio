class CreateTagsAndBlogPostTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :tags, :name, unique: true

    create_table :blog_post_tags do |t|
      t.references :blog_post, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :blog_post_tags, [ :blog_post_id, :tag_id ], unique: true
  end
end
