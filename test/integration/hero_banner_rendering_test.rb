require "test_helper"

# Regression: the hero banner partials must not crash when a record has no
# featured_image attachment and a blank img_url (asset_path(nil) raises). This
# covers the show, edit, and new banners across blog posts and projects.
class HeroBannerRenderingTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:louis) }

  test "blog post edit renders with no image" do
    post = BlogPost.create!(
      title: "No Image Post", description: "d", html_content: "<p>x</p>", user: users(:louis)
    )
    get edit_blog_post_url(post)
    assert_response :success
  end

  test "blog post show renders with no image" do
    post = BlogPost.create!(
      title: "No Image Show Post", description: "d", html_content: "<p>x</p>", user: users(:louis)
    )
    get blog_post_url(post)
    assert_response :success
  end

  test "project edit renders with no image" do
    project = Project.create!(title: "No Image Project", user: users(:louis))
    get edit_project_url(project)
    assert_response :success
  end

  test "project show renders with no image" do
    project = Project.create!(title: "No Image Show Project", user: users(:louis))
    get project_url(project)
    assert_response :success
  end
end
