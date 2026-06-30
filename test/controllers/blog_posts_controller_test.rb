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

  test "index eager-loads tags so the post list is not an N+1" do
    # Several published posts each carrying a tag: without includes(:tags) the
    # view's per-row `tags.any?`/`tags.map` loads tags once per post (scales with
    # N). With eager loading the tag-table query count stays small and constant.
    tag = tags(:rails7)
    6.times do |i|
      post = BlogPost.create!(
        title: "N Plus One Post #{i}",
        html_content: "<p>Body #{i}.</p>",
        img_url: "lb-portfolio.jpeg",
        user: users(:louis),
        status: :published,
        position: i
      )
      post.tags << tag
    end

    tag_queries = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      tag_queries += 1 if payload[:sql]&.match?(/FROM "tags"/i)
    end

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get blog_posts_url
    end

    assert_response :success
    # Fix => @all_tags (1) + a single preload (1). N+1 regression => one per post.
    assert_operator tag_queries, :<=, 3,
      "blog index must eager-load tags (saw #{tag_queries} tag queries — N+1 regression)"
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

  test "show does not leak a draft post to signed-out visitors" do
    draft = BlogPost.create!(
      title: "Hidden Draft Show",
      html_content: "<p>Secret draft body.</p>",
      user: users(:louis),
      status: :draft
    )

    # An unscoped lookup would return 200 and leak the body; the visibility
    # scope makes the record 404 for visitors (RecordNotFound is rescued to a
    # 404 response by ShowExceptions under the test env's :rescuable setting).
    # A 404 means the show template never rendered, so the body cannot leak.
    get blog_post_url(draft)
    assert_response :not_found
  end

  test "show does not leak a scheduled post to signed-out visitors" do
    scheduled = BlogPost.create!(
      title: "Hidden Scheduled Show",
      html_content: "<p>Secret scheduled body.</p>",
      user: users(:louis),
      status: :scheduled,
      scheduled_at: 2.days.from_now
    )

    get blog_post_url(scheduled)
    assert_response :not_found
  end

  test "show renders a draft post for the signed-in owner" do
    sign_in users(:louis)
    draft = BlogPost.create!(
      title: "Owner Draft Show",
      html_content: "<p>Owner can see this draft.</p>",
      user: users(:louis),
      status: :draft
    )

    get blog_post_url(draft)
    assert_response :success
    assert_includes response.body, "Owner can see this draft."
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

  # ---- Phase 4: split publish-button UI ----

  test "new renders the split publish button and schedule modal" do
    sign_in users(:louis)
    get new_blog_post_url
    assert_response :success
    assert_select "form[data-controller~=publish-form]"
    assert_select "input[data-publish-form-target=statusInput]"
    assert_select "input[data-publish-form-target=scheduledAtInput]"
    assert_select "input[type=datetime-local][data-publish-form-target=scheduleInput]"
    assert_select "button[data-action*='publish-form#publishNow']"
    assert_select "#schedulePostModal"
  end

  test "edit renders the split publish button" do
    sign_in users(:louis)
    get edit_blog_post_url(@blog_post)
    assert_response :success
    assert_select "button[data-action*='publish-form#saveChanges']"
  end

  test "edit renders for a scheduled post with a nil scheduled_at without crashing" do
    sign_in users(:louis)
    # A scheduled post can legitimately have a nil scheduled_at (no validation
    # enforces it). The form must not call strftime on nil and 500 the edit page.
    post = BlogPost.create!(
      title: "Scheduled Nil Time",
      img_url: "lb-portfolio.jpeg",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :scheduled,
      scheduled_at: nil
    )

    get edit_blog_post_url(post)
    assert_response :success
  end

  # ---- Phase 4: publish-intent on create/update ----

  test "create with status published publishes the post" do
    sign_in users(:louis)
    post blog_posts_url, params: { blog_post: {
      title: "Publish On Create",
      html_content: "<p>Body.</p>",
      status: "published"
    } }
    assert BlogPost.find_by(title: "Publish On Create").published?
  end

  test "create with status scheduled and a future time schedules the post" do
    sign_in users(:louis)
    post blog_posts_url, params: { blog_post: {
      title: "Schedule On Create",
      html_content: "<p>Body.</p>",
      status: "scheduled",
      scheduled_at: 2.days.from_now.strftime("%Y-%m-%dT%H:%M")
    } }
    created = BlogPost.find_by(title: "Schedule On Create")
    assert created.scheduled?
    assert created.scheduled_at.present?
  end

  test "create with status scheduled but a past time falls back to draft" do
    sign_in users(:louis)
    post blog_posts_url, params: { blog_post: {
      title: "Past Schedule On Create",
      html_content: "<p>Body.</p>",
      status: "scheduled",
      scheduled_at: 2.days.ago.strftime("%Y-%m-%dT%H:%M")
    } }
    assert BlogPost.find_by(title: "Past Schedule On Create").draft?
  end

  test "create with status scheduled but a blank time falls back to draft" do
    sign_in users(:louis)
    post blog_posts_url, params: { blog_post: {
      title: "Blank Schedule On Create",
      html_content: "<p>Body.</p>",
      status: "scheduled",
      scheduled_at: ""
    } }
    assert BlogPost.find_by(title: "Blank Schedule On Create").draft?
  end

  test "update with status published publishes a draft post" do
    sign_in users(:louis)
    draft = BlogPost.create!(
      title: "Draft To Update Publish",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )
    patch blog_post_url(draft), params: { blog_post: { status: "published" } }
    assert draft.reload.published?
  end

  # ---- Phase 4: publish / schedule / cancel_schedule member actions ----

  test "publish publishes a draft post for the owner" do
    sign_in users(:louis)
    draft = BlogPost.create!(
      title: "Draft To Publish",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )
    patch publish_blog_post_url(draft)
    assert draft.reload.published?
    assert_nil draft.scheduled_at
  end

  test "publish requires authentication" do
    draft = BlogPost.create!(
      title: "Guarded Publish",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )
    patch publish_blog_post_url(draft)
    assert_redirected_to new_user_session_url
    assert draft.reload.draft?
  end

  test "schedule with a future time schedules the post" do
    sign_in users(:louis)
    draft = BlogPost.create!(
      title: "To Schedule",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )
    patch schedule_blog_post_url(draft), params: { scheduled_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M") }
    assert draft.reload.scheduled?
    assert draft.scheduled_at.present?
  end

  test "schedule with a past time does not schedule" do
    sign_in users(:louis)
    draft = BlogPost.create!(
      title: "Past Schedule Member",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )
    patch schedule_blog_post_url(draft), params: { scheduled_at: 1.day.ago.strftime("%Y-%m-%dT%H:%M") }
    assert_not draft.reload.scheduled?
  end

  test "schedule with a blank time does not schedule" do
    sign_in users(:louis)
    draft = BlogPost.create!(
      title: "Blank Schedule Member",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )
    patch schedule_blog_post_url(draft), params: { scheduled_at: "" }
    assert_not draft.reload.scheduled?
  end

  test "schedule requires authentication" do
    draft = BlogPost.create!(
      title: "Guarded Schedule",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )
    patch schedule_blog_post_url(draft), params: { scheduled_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M") }
    assert_redirected_to new_user_session_url
    assert draft.reload.draft?
  end

  test "cancel_schedule reverts a scheduled post to draft" do
    sign_in users(:louis)
    scheduled = BlogPost.create!(
      title: "Cancel My Schedule",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :scheduled,
      scheduled_at: 1.day.from_now
    )
    patch cancel_schedule_blog_post_url(scheduled)
    assert scheduled.reload.draft?
    assert_nil scheduled.scheduled_at
  end

  test "cancel_schedule requires authentication" do
    scheduled = BlogPost.create!(
      title: "Guarded Cancel",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :scheduled,
      scheduled_at: 1.day.from_now
    )
    patch cancel_schedule_blog_post_url(scheduled)
    assert_redirected_to new_user_session_url
    assert scheduled.reload.scheduled?
  end

  # ---- Cross-user ownership (IDOR) ----
  # These act as a SIGNED-IN intruder against records owned by louis. The guards
  # scope every lookup to current_user, so the intruder's request finds nothing
  # (RecordNotFound -> 404) and never mutates louis's records. An unscoped lookup
  # would find and mutate them — these tests catch reverting that scoping.

  test "reorder only touches the intruder's own posts, never another owner's" do
    louis_post = BlogPost.create!(
      title: "Louis Only Reorder",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft,
      position: 5
    )
    intruder_post = blog_posts(:intruder_post)

    sign_in users(:intruder)
    # If reorder weren't scoped, louis_post (index 0) would become position 0.
    patch reorder_blog_posts_url, params: { ids: [ louis_post.id, intruder_post.id ] }, as: :json
    assert_response :success

    assert_equal 5, louis_post.reload.position, "an intruder must not reorder louis's posts"
    assert_equal 1, intruder_post.reload.position, "the intruder may reorder their own post"
  end

  test "publish on a post owned by another user is not found for the intruder" do
    louis_post = BlogPost.create!(
      title: "Louis Only Publish",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )

    sign_in users(:intruder)
    patch publish_blog_post_url(louis_post)
    assert_response :not_found
    assert louis_post.reload.draft?, "a non-owner must not be able to publish the post"
  end

  test "schedule on a post owned by another user is not found for the intruder" do
    louis_post = BlogPost.create!(
      title: "Louis Only Schedule",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )

    sign_in users(:intruder)
    patch schedule_blog_post_url(louis_post), params: { scheduled_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M") }
    assert_response :not_found
    assert louis_post.reload.draft?, "a non-owner must not be able to schedule the post"
  end

  test "cancel_schedule on a post owned by another user is not found for the intruder" do
    louis_post = BlogPost.create!(
      title: "Louis Only Cancel",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :scheduled,
      scheduled_at: 1.day.from_now
    )

    sign_in users(:intruder)
    patch cancel_schedule_blog_post_url(louis_post)
    assert_response :not_found
    assert louis_post.reload.scheduled?, "a non-owner must not be able to cancel the schedule"
  end

  test "ai_revise on a post owned by another user is not found for the intruder" do
    louis_post = BlogPost.create!(
      title: "Louis Only AI Revise",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )

    sign_in users(:intruder)
    with_env("ANTHROPIC_API_KEY", "sk-ant-test") do
      get ai_revise_blog_post_url(louis_post)
    end
    assert_response :not_found
  end

  test "revise_with_ai on a post owned by another user is not found for the intruder" do
    louis_post = BlogPost.create!(
      title: "Louis Only Revise With AI",
      html_content: "<p>x</p>",
      user: users(:louis),
      status: :draft
    )

    sign_in users(:intruder)
    with_env("ANTHROPIC_API_KEY", "sk-ant-test") do
      patch revise_with_ai_blog_post_url(louis_post), params: { blog_post: { prompt: "rewrite" } }
    end
    assert_response :not_found
    assert louis_post.reload.title == "Louis Only Revise With AI", "a non-owner must not revise the post"
  end
end
