require "test_helper"

class BlogPostSchemaTest < ActiveSupport::TestCase
  setup { @schema = BlogPostSchema.new.to_json_schema }

  test "exposes a named object schema" do
    assert_equal "blog_post", @schema[:name]
    assert_equal "object", @schema[:schema][:type]
  end

  test "declares the five expected properties" do
    props = @schema[:schema][:properties]
    assert_equal %i[title excerpt content image_query tag_ids].sort, props.keys.sort
    assert_equal "string", props[:title][:type]
    assert_equal "string", props[:excerpt][:type]
    assert_equal "string", props[:content][:type]
    assert_equal "string", props[:image_query][:type]
    assert_equal "array", props[:tag_ids][:type]
    assert_equal "integer", props[:tag_ids][:items][:type]
  end

  test "requires every field and forbids extras" do
    schema = @schema[:schema]
    assert_equal %w[title excerpt content image_query tag_ids].sort, schema[:required].sort
    assert_equal false, schema[:additionalProperties]
  end
end
