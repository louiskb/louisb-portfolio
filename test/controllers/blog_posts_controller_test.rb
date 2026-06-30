require "test_helper"

class BlogPostsControllerTest < ActionDispatch::IntegrationTest
  setup { @blog_post = blog_posts(:welcome) }

  test "index is public" do
    get blog_posts_url
    assert_response :success
  end

  test "show is public" do
    get blog_post_url(@blog_post)
    assert_response :success
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
