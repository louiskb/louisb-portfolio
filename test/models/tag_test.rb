require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "capitalizes the first letter of each word before saving" do
    tag = Tag.create!(name: "contact form")
    assert_equal "Contact Form", tag.name
  end

  test "preserves hyphens when capitalizing" do
    tag = Tag.create!(name: "transit-oriented design")
    assert_equal "Transit-Oriented Design", tag.name
  end

  test "name is required" do
    tag = Tag.new(name: "")
    assert_not tag.valid?
  end

  test "name uniqueness is case-insensitive" do
    Tag.create!(name: "Ruby")
    duplicate = Tag.new(name: "ruby")
    assert_not duplicate.valid?
  end

  test "a blog post has many tags through the join" do
    post = blog_posts(:welcome)
    assert_includes post.tags.map(&:name), "Heroku"
    assert_equal 3, post.tags.count
  end
end
