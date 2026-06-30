require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home is public" do
    get root_url
    assert_response :success
  end

  test "home hides featured draft projects from visitors but shows them to the owner" do
    # Title is already in String#capitalize canonical form because the homepage
    # renders project.title.capitalize.
    draft = Project.create!(
      title: "Draft homepage marker",
      description: "Featured but still a draft.",
      img_url: "lb-portfolio.jpeg",
      tech_stack: "Ruby",
      project_url: "https://example.com/hidden",
      personal_project: true,
      featured: true,
      user: users(:louis),
      status: :draft
    )

    get root_url
    assert_response :success
    assert_not_includes response.body, draft.title, "draft must not leak to visitors on the homepage"

    sign_in users(:louis)
    get root_url
    assert_response :success
    assert_includes response.body, draft.title, "owner must see the draft on the homepage"
  end
end
