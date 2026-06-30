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
