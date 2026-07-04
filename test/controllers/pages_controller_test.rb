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

  test "home renders the by-the-numbers section wired for count-up with live stats" do
    get root_url
    assert_response :success

    # The section is present and wired for scroll reveal.
    assert_select "section#by-the-numbers[data-controller~='scroll-reveal']"

    stats = HomeStats.new.to_h
    # Every stat number is wired to the count-up Stimulus controller.
    assert_select "[data-controller='count-up']", count: stats.size
    # The live technologies count (4 distinct across the two published fixtures)
    # renders as a real value (date-independent, unlike the year stats).
    assert_equal 4, stats[:technologies_count]
    assert_select "[data-count-up-target-value='#{stats[:technologies_count]}']"
  end

  test "home renders the black-hole scene wiring" do
    get root_path
    assert_select "[data-controller='black-hole']", 1
    assert_select "canvas[data-black-hole-target='canvas']", 1
    # Skip-link target from the layout must exist on the page.
    assert_select "main#main-content", 1
  end

  test "home renders a semantic footer element (black-hole end anchor)" do
    get root_path
    # The canvas engine parks the hole between the contact form and the
    # footer at the end of scroll — it needs a real <footer> element.
    assert_select "footer", 1
  end

  test "home shows up to three latest published posts and never drafts" do
    get root_path
    assert_select "section#latest-posts" do
      # Only published posts may appear, newest first, max 3.
      assert_select ".latest-post-card", { maximum: 3 }
    end
    draft_titles = BlogPost.where.not(status: :published).pluck(:title)
    draft_titles.each { |title| assert_no_match title, response.body }
  end

  test "home hides drafts in latest posts even for the signed-in owner" do
    sign_in users(:louis)
    get root_path
    draft_titles = BlogPost.where.not(status: :published).pluck(:title)
    draft_titles.each { |title| assert_no_match title, response.body }
  end

  test "home sections carry the depth-camera data attributes" do
    get root_path
    # 10 sections: hero, work, numbers, demo, stack, background, education,
    # about, blog (2 published fixture posts exist), contact.
    assert_select "[data-sec]", 10
    assert_select "[data-sec][data-role][data-ax]", 10
    assert_select "#contact form", 1 # engine end-anchor contract
  end

  test "privacy_policy is public and renders" do
    get privacy_policy_url
    assert_response :success
    assert_includes response.body, "PostHog", "privacy policy must disclose the analytics provider"
  end

  test "terms_of_service is public and renders" do
    get terms_of_service_url
    assert_response :success
    assert_includes response.body, "AI-assisted", "terms must disclose AI-assisted content"
  end

  # ---- Layout head regression tests (2026-07-04 audit sweep) ----

  test "layout declares the page language and a meta description" do
    get root_url
    assert_response :success
    assert_select "html[lang=en]"
    assert_select "meta[name=description]" do |metas|
      assert metas.first["content"].present?, "meta description must not be empty"
    end
    assert_select "meta[name=theme-color]"
  end
end
