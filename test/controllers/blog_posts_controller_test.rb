require "test_helper"

class BlogPostsControllerTest < ActionDispatch::IntegrationTest
  setup { @blog_post = blog_posts(:welcome) }

  test "index is public" do
    get blog_posts_url
    assert_response :success
  end

  test "index hides draft posts from visitors but shows them to the owner" do
    draft = BlogPost.create!(
      title: "Secret Draft Post",
      description: "Still drafting.",
      img_url: "lb-portfolio.jpeg",
      html_content: "<p>Draft body.</p>",
      user: users(:louis),
      status: :draft
    )

    get blog_posts_url
    assert_response :success
    assert_not_includes response.body, draft.title, "draft must not leak to visitors"

    sign_in users(:louis)
    get blog_posts_url
    assert_response :success
    assert_includes response.body, draft.title, "owner must see the draft"
  end

  test "uploading a featured_image via the form attaches it" do
    sign_in users(:louis)
    assert_difference "BlogPost.count", 1 do
      post blog_posts_url, params: { blog_post: {
        title: "Post With Upload",
        description: "Has an uploaded image.",
        img_url: "lb-portfolio.jpeg",
        html_content: "<p>Body.</p>",
        featured_image: fixture_file_upload("test_image.png", "image/png")
      } }
    end
    assert BlogPost.last.featured_image.attached?
  end

  test "index paginates published posts nine per page" do
    # 12 published posts with explicit positions 0..11; the two fixtures have a
    # nil position so they sort last. Page 1 shows positions 0–8, page 2 the rest.
    12.times do |i|
      BlogPost.create!(
        title: format("Paginated Post %02d", i),
        description: "A paginated post number #{i}.",
        img_url: "lb-portfolio.jpeg",
        html_content: "<p>Body #{i}.</p>",
        position: i,
        user: users(:louis)
      )
    end

    get blog_posts_url
    assert_response :success
    assert_includes response.body, "Paginated Post 00"
    assert_not_includes response.body, "Paginated Post 11", "post at position 11 belongs on page 2"

    get blog_posts_url(page: 2)
    assert_response :success
    assert_includes response.body, "Paginated Post 11"
  end

  test "index filters by title with ?q" do
    get blog_posts_url(q: "Deploying")
    assert_response :success
    assert_includes response.body, "Deploying Rails to Heroku"
    assert_not_includes response.body, "Welcome to my blog"
  end

  test "index filters by tag with ?tag_ids[]" do
    # Only `deploying` carries the PostgreSQL tag (see fixtures).
    get blog_posts_url(tag_ids: [ tags(:postgresql).id ])
    assert_response :success
    assert_includes response.body, "Deploying Rails to Heroku"
    assert_not_includes response.body, "Welcome to my blog"
  end

  test "creating a manual rich-text post (body, no html_content) saves and renders" do
    sign_in users(:louis)
    assert_difference "BlogPost.count", 1 do
      post blog_posts_url, params: { blog_post: {
        title: "A Manual Rich Text Post",
        body: "<h2>Heading</h2><p>This was written in the editor.</p>"
      } }
    end
    assert_response :redirect

    created = BlogPost.last
    assert created.body.present?
    assert created.html_content.blank?

    get blog_post_url(created)
    assert_response :success
    assert_includes response.body, "This was written in the editor."
  end

  test "show is public" do
    get blog_post_url(@blog_post)
    assert_response :success
  end

  test "show resolves by friendly slug" do
    post = BlogPost.create!(
      title: "Resolving By Slug",
      description: "A description.",
      img_url: "lb-portfolio.jpeg",
      html_content: "<p>Body.</p>",
      user: users(:louis)
    )

    get blog_post_url(post)
    assert_response :success
    assert_equal "/blog_posts/resolving-by-slug", path
  end

  test "index renders drag handles for the signed-in owner" do
    sign_in users(:louis)
    get blog_posts_url
    assert_response :success
    assert_select "[data-controller=sortable]"
    assert_select ".drag-handle"
  end

  test "reorder persists new position order when signed in" do
    sign_in users(:louis)
    a = blog_posts(:welcome)
    b = blog_posts(:deploying)

    patch reorder_blog_posts_url, params: { ids: [ b.id, a.id ] }, as: :json
    assert_response :success

    assert_equal 0, b.reload.position
    assert_equal 1, a.reload.position
  end

  test "reorder requires authentication" do
    a = blog_posts(:welcome)
    b = blog_posts(:deploying)

    # The reorder request is JSON, so Devise returns 401 rather than redirecting.
    patch reorder_blog_posts_url, params: { ids: [ b.id, a.id ] }, as: :json
    assert_response :unauthorized
  end

  test "new requires authentication" do
    get new_blog_post_url
    assert_redirected_to new_user_session_url
  end

  test "new succeeds when signed in" do
    sign_in users(:louis)
    get new_blog_post_url
    assert_response :success
  end

  test "create succeeds when signed in" do
    sign_in users(:louis)
    assert_difference "BlogPost.count", 1 do
      post blog_posts_url, params: { blog_post: {
        title: "A brand new post",
        description: "Something I learned today.",
        img_url: "lb-portfolio.jpeg",
        html_content: "<p>The body of the post.</p>"
      } }
    end
    assert_response :redirect
  end

  test "create requires authentication" do
    assert_no_difference "BlogPost.count" do
      post blog_posts_url, params: { blog_post: { title: "Nope" } }
    end
    assert_redirected_to new_user_session_url
  end
end
