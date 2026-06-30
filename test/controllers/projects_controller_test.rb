require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:sipfolio) }

  test "index is public" do
    get projects_url
    assert_response :success
  end

  test "show is public" do
    get project_url(@project)
    assert_response :success
  end

  test "index hides draft projects from visitors but shows them to the owner" do
    draft = Project.create!(
      title: "Secret Draft Project",
      description: "Not ready yet.",
      img_url: "lb-portfolio.jpeg",
      tech_stack: "Ruby",
      project_url: "https://example.com/secret",
      personal_project: true,
      user: users(:louis),
      status: :draft
    )

    get projects_url
    assert_response :success
    assert_not_includes response.body, draft.title, "draft must not leak to visitors"

    sign_in users(:louis)
    get projects_url
    assert_response :success
    assert_includes response.body, draft.title, "owner must see the draft"
  end

  test "uploading a featured_image via the form attaches it" do
    sign_in users(:louis)
    assert_difference "Project.count", 1 do
      post projects_url, params: { project: {
        title: "Project With Upload",
        description: "Has an uploaded image.",
        img_url: "market-sensei.jpg",
        tech_stack: "Rails",
        project_url: "https://example.com/upload",
        personal_project: true,
        featured_image: fixture_file_upload("test_image.png", "image/png")
      } }
    end
    assert Project.last.featured_image.attached?
  end

  test "show succeeds when signed in" do
    sign_in users(:louis)
    get project_url(@project)
    assert_response :success
  end

  test "show resolves by friendly slug" do
    sign_in users(:louis)
    project = Project.create!(
      title: "Resolving Project Slug",
      description: "A description.",
      img_url: "lb-portfolio.jpeg",
      tech_stack: "Python",
      project_url: "https://example.com/p",
      user: users(:louis)
    )

    get project_url(project)
    assert_response :success
    assert_equal "/projects/resolving-project-slug", path
  end

  test "new succeeds when signed in" do
    sign_in users(:louis)
    get new_project_url
    assert_response :success
  end

  test "index renders drag handles for the signed-in owner" do
    sign_in users(:louis)
    get projects_url
    assert_response :success
    assert_select "[data-controller=sortable]"
    assert_select ".drag-handle"
  end

  test "reorder persists new position order when signed in" do
    sign_in users(:louis)
    a = projects(:sipfolio)
    b = projects(:findadoc)

    patch reorder_projects_url, params: { ids: [ b.id, a.id ] }, as: :json
    assert_response :success

    assert_equal 0, b.reload.position
    assert_equal 1, a.reload.position
  end

  test "reorder requires authentication" do
    a = projects(:sipfolio)
    b = projects(:findadoc)

    # The reorder request is JSON, so Devise returns 401 rather than redirecting.
    patch reorder_projects_url, params: { ids: [ b.id, a.id ] }, as: :json
    assert_response :unauthorized
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
