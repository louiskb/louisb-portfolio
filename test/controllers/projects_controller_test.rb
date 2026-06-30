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

  test "show does not leak a draft project to signed-out visitors" do
    draft = Project.create!(
      title: "Hidden Draft Project Show",
      description: "Secret draft.",
      img_url: "lb-portfolio.jpeg",
      tech_stack: "Ruby",
      project_url: "https://example.com/secret-show",
      personal_project: true,
      user: users(:louis),
      status: :draft
    )

    # An unscoped lookup would return 200 and leak the project; the visibility
    # scope makes the record 404 for visitors (RecordNotFound is rescued to a
    # 404 response by ShowExceptions under the test env's :rescuable setting).
    # A 404 means the show template never rendered, so nothing can leak.
    get project_url(draft)
    assert_response :not_found
  end

  test "show does not leak a scheduled project to signed-out visitors" do
    scheduled = Project.create!(
      title: "Hidden Scheduled Project Show",
      description: "Secret scheduled.",
      img_url: "lb-portfolio.jpeg",
      tech_stack: "Ruby",
      project_url: "https://example.com/secret-scheduled",
      personal_project: true,
      user: users(:louis),
      status: :scheduled,
      scheduled_at: 2.days.from_now
    )

    get project_url(scheduled)
    assert_response :not_found
  end

  test "show renders a draft project for the signed-in owner" do
    sign_in users(:louis)
    draft = Project.create!(
      title: "Owner Draft Project Show",
      description: "Owner can see this draft.",
      img_url: "lb-portfolio.jpeg",
      tech_stack: "Ruby",
      project_url: "https://example.com/owner-draft",
      personal_project: true,
      user: users(:louis),
      status: :draft
    )

    get project_url(draft)
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

  # ---- Phase 4: split publish-button UI ----

  test "new renders the split publish button and schedule modal" do
    sign_in users(:louis)
    get new_project_url
    assert_response :success
    assert_select "form[data-controller~=publish-form]"
    assert_select "input[data-publish-form-target=statusInput]"
    assert_select "input[type=datetime-local][data-publish-form-target=scheduleInput]"
    assert_select "button[data-action*='publish-form#publishNow']"
    assert_select "#schedulePostModal"
  end

  test "edit renders the split publish button" do
    sign_in users(:louis)
    get edit_project_url(@project)
    assert_response :success
    assert_select "button[data-action*='publish-form#saveChanges']"
  end

  # ---- Phase 4: publish-intent on create/update ----

  test "create with status published publishes the project" do
    sign_in users(:louis)
    post projects_url, params: { project: {
      title: "Publish On Create Project",
      tech_stack: "Rails",
      personal_project: true,
      status: "published"
    } }
    assert Project.find_by(title: "Publish On Create Project").published?
  end

  test "create with status scheduled and a future time schedules the project" do
    sign_in users(:louis)
    post projects_url, params: { project: {
      title: "Schedule On Create Project",
      tech_stack: "Rails",
      personal_project: true,
      status: "scheduled",
      scheduled_at: 2.days.from_now.strftime("%Y-%m-%dT%H:%M")
    } }
    created = Project.find_by(title: "Schedule On Create Project")
    assert created.scheduled?
    assert created.scheduled_at.present?
  end

  test "create with status scheduled but a past time falls back to draft" do
    sign_in users(:louis)
    post projects_url, params: { project: {
      title: "Past Schedule On Create Project",
      tech_stack: "Rails",
      personal_project: true,
      status: "scheduled",
      scheduled_at: 2.days.ago.strftime("%Y-%m-%dT%H:%M")
    } }
    assert Project.find_by(title: "Past Schedule On Create Project").draft?
  end

  # ---- Phase 4: publish / schedule / cancel_schedule member actions ----

  test "publish publishes a draft project for the owner" do
    sign_in users(:louis)
    draft = Project.create!(title: "Draft Project Publish", user: users(:louis), status: :draft)
    patch publish_project_url(draft)
    assert draft.reload.published?
    assert_nil draft.scheduled_at
  end

  test "publish requires authentication" do
    draft = Project.create!(title: "Guarded Project Publish", user: users(:louis), status: :draft)
    patch publish_project_url(draft)
    assert_redirected_to new_user_session_url
    assert draft.reload.draft?
  end

  test "schedule with a future time schedules the project" do
    sign_in users(:louis)
    draft = Project.create!(title: "Project To Schedule", user: users(:louis), status: :draft)
    patch schedule_project_url(draft), params: { scheduled_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M") }
    assert draft.reload.scheduled?
    assert draft.scheduled_at.present?
  end

  test "schedule with a past time does not schedule the project" do
    sign_in users(:louis)
    draft = Project.create!(title: "Project Past Schedule", user: users(:louis), status: :draft)
    patch schedule_project_url(draft), params: { scheduled_at: 1.day.ago.strftime("%Y-%m-%dT%H:%M") }
    assert_not draft.reload.scheduled?
  end

  test "cancel_schedule reverts a scheduled project to draft" do
    sign_in users(:louis)
    scheduled = Project.create!(
      title: "Cancel Project Schedule",
      user: users(:louis),
      status: :scheduled,
      scheduled_at: 1.day.from_now
    )
    patch cancel_schedule_project_url(scheduled)
    assert scheduled.reload.draft?
    assert_nil scheduled.scheduled_at
  end

  test "cancel_schedule requires authentication" do
    scheduled = Project.create!(
      title: "Guarded Project Cancel",
      user: users(:louis),
      status: :scheduled,
      scheduled_at: 1.day.from_now
    )
    patch cancel_schedule_project_url(scheduled)
    assert_redirected_to new_user_session_url
    assert scheduled.reload.scheduled?
  end
end
