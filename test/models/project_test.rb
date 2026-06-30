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
end
