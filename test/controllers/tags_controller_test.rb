require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  test "create requires authentication" do
    assert_no_difference "Tag.count" do
      post tags_url, params: { tag: { name: "Hotwire" } }, as: :json
    end
    assert_response :unauthorized
  end

  test "create makes a normalized tag and returns JSON" do
    sign_in users(:louis)
    assert_difference "Tag.count", 1 do
      post tags_url, params: { tag: { name: "hotwire turbo" } }, as: :json
    end
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Hotwire Turbo", body["name"]
  end

  test "create rejects a blank name" do
    sign_in users(:louis)
    assert_no_difference "Tag.count" do
      post tags_url, params: { tag: { name: " " } }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "create returns the existing tag for a case-insensitive duplicate" do
    sign_in users(:louis)
    existing = tags(:heroku)
    assert_no_difference "Tag.count" do
      post tags_url, params: { tag: { name: "heroku" } }, as: :json
    end
    assert_response :success
    assert_equal existing.id, JSON.parse(response.body)["id"]
  end

  test "destroy removes the tag globally" do
    sign_in users(:louis)
    tag = tags(:postgresql)
    assert_difference "Tag.count", -1 do
      delete tag_url(tag), as: :json
    end
    assert_response :no_content
  end
end
