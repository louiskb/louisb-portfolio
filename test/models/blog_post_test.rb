require "test_helper"

class BlogPostTest < ActiveSupport::TestCase
  test "new blog post defaults to published status" do
    assert_equal "published", BlogPost.new.status
  end

  test "publishing columns are present" do
    columns = BlogPost.column_names
    %w[slug status scheduled_at featured blog_excerpt featured_image_caption
       ai_generated human_generated author position].each do |column|
      assert_includes columns, column, "expected blog_posts to have #{column}"
    end
  end

  test "includes the Publishable concern" do
    assert_includes BlogPost.ancestors, Publishable
  end

  test "can attach a featured image via the :test service" do
    post = blog_posts(:welcome)
    post.featured_image.attach(
      io: file_fixture("test_image.png").open,
      filename: "test_image.png",
      content_type: "image/png"
    )

    assert post.featured_image.attached?
  end

  test "has a rich text body that round-trips to plain text" do
    post = blog_posts(:welcome)
    post.body = "<h2>Hello</h2><p>This is a rich text body.</p>"
    post.save!

    assert post.body.present?
    assert_includes post.reload.body.to_plain_text, "This is a rich text body."
  end

  test "generates a slug from the title" do
    post = BlogPost.create!(
      title: "My First Rails Post",
      description: "A description.",
      img_url: "lb-portfolio.jpeg",
      tags: "Ruby",
      html_content: "<p>Body.</p>",
      user: users(:louis)
    )

    assert_equal "my-first-rails-post", post.slug
    assert_equal post, BlogPost.friendly.find("my-first-rails-post")
  end
end
