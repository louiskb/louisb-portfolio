require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "new project defaults to published status" do
    assert_equal "published", Project.new.status
  end

  test "publishing columns are present" do
    columns = Project.column_names
    %w[slug status scheduled_at position].each do |column|
      assert_includes columns, column, "expected projects to have #{column}"
    end
  end

  test "includes the Publishable concern" do
    assert_includes Project.ancestors, Publishable
  end

  test "generates a slug from the title" do
    project = Project.create!(
      title: "My Trading Bot",
      description: "A description.",
      img_url: "lb-portfolio.jpeg",
      tech_stack: "Python",
      project_url: "https://example.com/bot",
      user: users(:louis)
    )

    assert_equal "my-trading-bot", project.slug
    assert_equal project, Project.friendly.find("my-trading-bot")
  end
end
