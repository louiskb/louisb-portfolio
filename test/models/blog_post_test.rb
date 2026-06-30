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
    post = BlogPost.create!(
      title: "Rich Text Post",
      body: "<h2>Hello</h2><p>This is a rich text body.</p>",
      user: users(:louis)
    )

    assert post.body.present?
    assert_includes post.reload.body.to_plain_text, "This is a rich text body."
  end

  test "existing html_content-only fixture posts are valid" do
    assert blog_posts(:welcome).valid?, blog_posts(:welcome).errors.full_messages.to_sentence
  end

  test "a body-only post is valid" do
    post = BlogPost.new(title: "Manual Post", body: "<p>Just rich text.</p>", user: users(:louis))
    assert post.valid?, post.errors.full_messages.to_sentence
  end

  test "a post with both body and html_content is invalid" do
    post = BlogPost.new(
      title: "Conflicted Post",
      html_content: "<p>Raw HTML.</p>",
      body: "<p>Rich text too.</p>",
      user: users(:louis)
    )

    assert_not post.valid?
    assert_includes post.errors[:base].to_sentence, "only have rich text content or HTML content"
  end

  test "related_posts finds published posts sharing a tag" do
    # welcome and deploying both carry the "Heroku" tag (see fixtures).
    related = blog_posts(:welcome).related_posts
    assert_includes related, blog_posts(:deploying)
    assert_not_includes related, blog_posts(:welcome), "must exclude itself"
    assert_operator related.size, :<=, 3
  end

  test "related_posts is empty when the post has no tags" do
    post = BlogPost.create!(title: "Tagless", html_content: "<p>Hi.</p>", user: users(:louis))
    assert_empty post.related_posts
  end

  test "reading_time returns a string" do
    assert_kind_of String, blog_posts(:welcome).reading_time
    assert_match(/min read/, blog_posts(:welcome).reading_time)
  end

  test "set_author stamps Louis Bourne before validation" do
    post = BlogPost.new(title: "Authored", html_content: "<p>Hi.</p>", user: users(:louis))
    post.valid?
    assert_equal "Louis Bourne", post.author
  end

  test "generates a slug from the title" do
    post = BlogPost.create!(
      title: "My First Rails Post",
      description: "A description.",
      img_url: "lb-portfolio.jpeg",
      html_content: "<p>Body.</p>",
      user: users(:louis)
    )

    assert_equal "my-first-rails-post", post.slug
    assert_equal post, BlogPost.friendly.find("my-first-rails-post")
  end
end
