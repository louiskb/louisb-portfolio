require "test_helper"

class BlogPostAiServiceTest < ActiveSupport::TestCase
  # --- Test doubles --------------------------------------------------------
  # A fake RubyLLM response: just exposes the canned parsed Hash via #content.
  FakeAiResponse = Struct.new(:content)

  # A fake RubyLLM chat: the fluent builder methods return self, and #ask
  # returns the canned response — so no network call ever happens.
  class FakeChat
    def initialize(content)
      @response = FakeAiResponse.new(content)
    end

    def with_instructions(*) = self
    def with_schema(*) = self
    def ask(*) = @response
  end

  # A real Net::HTTPSuccess subclass so `response.is_a?(Net::HTTPSuccess)` passes,
  # with a canned body — lets us drive fetch_image_html's markup branch in tests.
  class FakeHttpSuccess < Net::HTTPSuccess
    def initialize(body)
      super("1.1", "200", "OK")
      @fake_body = body
    end

    def body = @fake_body
  end

  setup do
    @user = users(:louis)
    @service = BlogPostAiService.new(@user)
  end

  def ai_payload(overrides = {})
    {
      "title" => "Deploying Rails on Fly.io",
      "excerpt" => "A short, practical guide to shipping Rails on Fly.io.",
      "content" => "<h2>Intro</h2><p>The body of the generated post.</p>",
      "image_query" => "ruby code",
      "tag_ids" => []
    }.merge(overrides)
  end

  # --- create_from_prompt --------------------------------------------------
  test "create_from_prompt builds a saved AI post with html_content, img_url, and filtered tags" do
    payload = ai_payload(
      "tag_ids" => [ tags(:rails7).id, 999_999 ] # one real id, one hallucinated
    )
    unsplash = {
      url: "https://images.unsplash.com/fake.jpg",
      photographer: "Jane Dev",
      photographer_url: "https://unsplash.com/@jane",
      photo_url: "https://unsplash.com/photos/x"
    }

    post = nil
    RubyLLM.stub(:chat, FakeChat.new(payload)) do
      @service.stub(:fetch_unsplash_data, unsplash) do
        post = @service.create_from_prompt("Write about Fly.io deploys")
      end
    end

    assert post.persisted?, "the AI post should be saved"
    assert post.ai_generated?, "ai_generated should be true"
    assert_not post.human_generated?, "a fresh AI post is not human-revised"
    assert_equal "Deploying Rails on Fly.io", post.title
    assert_equal "A short, practical guide to shipping Rails on Fly.io.", post.blog_excerpt
    assert_includes post.html_content, "The body of the generated post."
    assert post.body.to_plain_text.blank?, "AI posts use html_content, not body"
    assert_equal "https://images.unsplash.com/fake.jpg", post.img_url
    assert post.featured_image_caption.present?, "Unsplash attribution caption should be set"
    assert_equal [ tags(:rails7).id ], post.tag_ids, "hallucinated tag id must be filtered out"
    assert_equal "Louis Bourne", post.author, "author is stamped by the model"
  end

  test "create_from_prompt with a scheduled status and future time builds a scheduled post" do
    future = 3.days.from_now.change(usec: 0)

    post = nil
    RubyLLM.stub(:chat, FakeChat.new(ai_payload)) do
      @service.stub(:fetch_unsplash_data, nil) do
        post = @service.create_from_prompt("Topic", status: :scheduled, scheduled_at: future)
      end
    end

    assert post.persisted?
    assert post.scheduled?, "the requested scheduled status must be honoured, not silently published"
    assert_equal future.to_i, post.scheduled_at.to_i, "the requested publish time must be persisted"
  end

  test "create_from_prompt skips Unsplash when a custom image_url is supplied" do
    post = nil
    RubyLLM.stub(:chat, FakeChat.new(ai_payload)) do
      # If Unsplash were attempted this stub would make it explode; it must not run.
      @service.stub(:fetch_unsplash_data, ->(*) { flunk "Unsplash must be skipped when image_url given" }) do
        post = @service.create_from_prompt("Topic", image_url: "https://example.com/custom.jpg")
      end
    end

    assert post.persisted?
    assert_equal "https://example.com/custom.jpg", post.img_url
    assert_nil post.featured_image_caption, "custom URL means no Unsplash attribution"
  end

  # --- revise_blog_post ----------------------------------------------------
  test "revise_blog_post nils the body and flips both AI flags" do
    post = BlogPost.create!(
      title: "Manual Post",
      body: "<p>Original manual body written in the editor.</p>",
      user: @user
    )
    assert post.body.present?, "precondition: post starts with a rich-text body"

    payload = ai_payload(
      "title" => "Revised Title",
      "content" => "<h2>Revised</h2><p>Freshly revised content.</p>"
    )

    RubyLLM.stub(:chat, FakeChat.new(payload)) do
      @service.stub(:fetch_unsplash_data, nil) do
        @service.revise_blog_post(post, "Make it punchier")
      end
    end

    post.reload
    assert_equal "Revised Title", post.title, "save must have succeeded with the new content"
    assert_includes post.html_content, "Freshly revised content."
    assert post.body.to_plain_text.blank?, "the rich-text body should be cleared after AI revision"
    assert post.ai_generated?, "ai_generated should be true after revision"
    assert post.human_generated?, "human_generated should be true after revision"
  end

  test "revise_blog_post with a scheduled status and future time schedules the post" do
    post = BlogPost.create!(
      title: "Draft To Revise And Schedule",
      html_content: "<p>Original.</p>",
      user: @user,
      status: :draft
    )
    future = 4.days.from_now.change(usec: 0)

    RubyLLM.stub(:chat, FakeChat.new(ai_payload)) do
      @service.stub(:fetch_unsplash_data, nil) do
        @service.revise_blog_post(post, "revise it", status: :scheduled, scheduled_at: future)
      end
    end

    post.reload
    assert post.scheduled?, "the requested scheduled status must be honoured"
    assert_equal future.to_i, post.scheduled_at.to_i, "the requested publish time must be persisted"
  end

  test "revise_blog_post preserves the existing scheduled_at when scheduled with no new time" do
    original_time = 3.days.from_now.change(usec: 0)
    post = BlogPost.create!(
      title: "Scheduled Post To Revise",
      html_content: "<p>Original scheduled body.</p>",
      user: @user,
      status: :scheduled,
      scheduled_at: original_time
    )

    payload = ai_payload("title" => "Revised Scheduled", "content" => "<h2>R</h2><p>New body.</p>")

    # Mirrors the AI-revise form: it submits the current status (scheduled) but
    # NO scheduled_at, so the service is called with status: :scheduled, nil time.
    RubyLLM.stub(:chat, FakeChat.new(payload)) do
      @service.stub(:fetch_unsplash_data, nil) do
        @service.revise_blog_post(post, "tighten it", status: :scheduled, scheduled_at: nil)
      end
    end

    post.reload
    assert post.scheduled?, "post must remain scheduled after an AI revision"
    assert_not_nil post.scheduled_at, "the existing publish time must not be wiped to nil"
    assert_equal original_time.to_i, post.scheduled_at.to_i,
      "the original scheduled_at must be preserved intact"
  end

  test "revise_blog_post falls back to draft when scheduled with no usable time" do
    post = BlogPost.create!(
      title: "Draft Post To Revise",
      html_content: "<p>Original draft body.</p>",
      user: @user,
      status: :draft
    )

    payload = ai_payload("content" => "<h2>R</h2><p>New body.</p>")

    RubyLLM.stub(:chat, FakeChat.new(payload)) do
      @service.stub(:fetch_unsplash_data, nil) do
        @service.revise_blog_post(post, "tighten it", status: :scheduled, scheduled_at: nil)
      end
    end

    post.reload
    assert post.draft?, "a scheduled status with no usable time must fall back to draft"
    assert_nil post.scheduled_at
  end

  # --- Unsplash graceful degradation ---------------------------------------
  test "an Unsplash HTTP failure leaves the content intact and the post still saves" do
    with_env("UNSPLASH_ACCESS_KEY", "test-unsplash-key") do
      payload = ai_payload(
        "content" => "<h2>Solo</h2><p>Just text, no image placeholder.</p>"
      )
      raising = ->(*) { raise StandardError, "network down" }

      post = nil
      RubyLLM.stub(:chat, FakeChat.new(payload)) do
        Net::HTTP.stub(:start, raising) do
          post = @service.create_from_prompt("Write something")
        end
      end

      assert post.persisted?, "the post must save even when Unsplash raises"
      assert_equal "<h2>Solo</h2><p>Just text, no image placeholder.</p>", post.html_content
      assert_nil post.img_url, "a failed Unsplash fetch yields no image url"
    end
  end

  test "no Unsplash HTTP is attempted when UNSPLASH_ACCESS_KEY is absent" do
    with_env("UNSPLASH_ACCESS_KEY", nil) do
      payload = ai_payload(
        "content" => "<h2>Top</h2><!-- IMAGE: ruby code --><p>More body text.</p>"
      )
      no_http = ->(*) { flunk "Unsplash HTTP must not be attempted without an access key" }

      post = nil
      RubyLLM.stub(:chat, FakeChat.new(payload)) do
        Net::HTTP.stub(:start, no_http) do
          post = @service.create_from_prompt("Write something")
        end
      end

      assert post.persisted?
      assert_nil post.img_url
      assert_not_includes post.html_content, "<!-- IMAGE:", "image placeholder is stripped to empty when no key"
    end
  end

  # --- XSS hardening: hostile Unsplash fields ------------------------------
  test "figcaption_html escapes a hostile photographer name and collapses non-http hrefs" do
    data = {
      url: "https://images.unsplash.com/ok.jpg",
      photographer: '"><script>alert(1)</script>',
      photographer_url: "javascript:alert(1)",
      photo_url: "javascript:alert(document.cookie)"
    }

    html = @service.send(:figcaption_html, data)

    assert_not_includes html, "<script>", "the photographer name must be HTML-escaped, not raw"
    assert_includes html, "&lt;script&gt;", "the script tag must appear escaped"
    assert_not_includes html, "javascript:", "non-http(s) hrefs must collapse to #"
    assert_includes html, "href='#'", "a javascript: scheme must become #"
  end

  test "fetch_image_html escapes hostile Unsplash fields and collapses non-http schemes" do
    hostile_json = {
      "urls" => { "regular" => "javascript:alert(1)" },
      "user" => {
        "name" => '"><script>alert(1)</script>',
        "links" => { "html" => "javascript:alert(2)" }
      },
      "links" => { "html" => "javascript:alert(3)" }
    }.to_json

    with_env("UNSPLASH_ACCESS_KEY", "test-unsplash-key") do
      Net::HTTP.stub(:start, ->(*) { FakeHttpSuccess.new(hostile_json) }) do
        html = @service.send(:fetch_image_html, '"><script>q</script>')

        assert_includes html, "<figure", "the success markup branch must have executed"
        assert_not_includes html, "<script>", "hostile fields must be HTML-escaped, not raw"
        assert_includes html, "&lt;script&gt;", "the script tag must appear escaped"
        assert_not_includes html, "javascript:", "non-http(s) src/href must collapse to #"
      end
    end
  end
end
