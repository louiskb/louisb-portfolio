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
      tags: "Ruby",
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
        tags: "Ruby",
        html_content: "<p>Body.</p>",
        featured_image: fixture_file_upload("test_image.png", "image/png")
      } }
    end
    assert BlogPost.last.featured_image.attached?
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
      tags: "Ruby",
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
        tags: "Ruby . Testing",
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
