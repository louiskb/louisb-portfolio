class CreateBlogPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :blog_posts do |t|
      t.string :title
      t.text :description
      t.string :img_url
      t.string :tags
      t.text :html_content
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
