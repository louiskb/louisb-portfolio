require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:sipfolio) }

  test "index is public" do
    get projects_url
    assert_response :success
  end

  test "show requires authentication" do
    get project_url(@project)
    assert_redirected_to new_user_session_url
  end

  test "show succeeds when signed in" do
    sign_in users(:louis)
    get project_url(@project)
    assert_response :success
  end

  test "new succeeds when signed in" do
    sign_in users(:louis)
    get new_project_url
    assert_response :success
  end

  test "create succeeds when signed in" do
    sign_in users(:louis)
    assert_difference "Project.count", 1 do
      post projects_url, params: { project: {
        title: "Market Sensei",
        description: "An AI trading dashboard.",
        img_url: "market-sensei-dashboard-screenshot.jpg",
        tech_stack: "Rails, Hotwire",
        project_url: "https://example.com/market-sensei",
        github_url: "https://github.com/louiskb/market-sensei",
        personal_project: true,
        private_repo: false,
        featured: false
      } }
    end
    assert_response :redirect
  end
end
