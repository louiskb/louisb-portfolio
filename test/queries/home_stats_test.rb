require "test_helper"

class HomeStatsTest < ActiveSupport::TestCase
  test "projects_count counts only published projects" do
    Project.create!(title: "Hidden draft project", user: users(:louis), status: :draft)

    stats = HomeStats.new.to_h
    assert_equal Project.published.count, stats[:projects_count]
    assert_equal 2, stats[:projects_count], "both fixture projects are published"
  end

  test "blog_posts_count counts only published blog posts" do
    BlogPost.create!(
      title: "Hidden draft post",
      user: users(:louis),
      status: :draft,
      html_content: "<p>still a draft</p>"
    )

    stats = HomeStats.new.to_h
    assert_equal BlogPost.published.count, stats[:blog_posts_count]
    assert_equal 2, stats[:blog_posts_count], "both fixture posts are published"
  end

  test "technologies_count de-duplicates technologies shared across projects" do
    # Fixtures use the canonical " . " (dot-space) separator, matching seeds and
    # the project form hint: sipfolio = "Rails . Bootstrap . PostgreSQL",
    #                        findadoc = "Rails . Leaflet . PostgreSQL".
    # Distinct across both: rails, bootstrap, postgresql, leaflet => 4.
    assert_equal 4, HomeStats.new.to_h[:technologies_count]
  end

  test "technologies_count treats different casings as one technology" do
    Project.create!(
      title: "Caps project",
      user: users(:louis),
      status: :published,
      tech_stack: "RAILS . rails . Rails"
    )

    # RAILS / rails / Rails all collapse into the existing "rails" — still 4.
    assert_equal 4, HomeStats.new.to_h[:technologies_count]
  end

  test "technologies_count ignores draft projects' tech" do
    Project.create!(
      title: "Draft tech project",
      user: users(:louis),
      status: :draft,
      tech_stack: "Elixir . Phoenix"
    )

    # Draft tech is excluded — count unchanged at 4.
    assert_equal 4, HomeStats.new.to_h[:technologies_count]
  end

  test "year stats are non-negative integers" do
    stats = HomeStats.new.to_h

    assert_kind_of Integer, stats[:years_coding]
    assert_kind_of Integer, stats[:years_trading]
    assert_operator stats[:years_coding], :>=, 0
    assert_operator stats[:years_trading], :>=, 0
  end
end
