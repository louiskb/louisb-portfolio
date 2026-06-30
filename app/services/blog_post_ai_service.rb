require "net/http"
require "json"
require "openssl"

# Generates and revises blog posts with Anthropic Claude (via ruby_llm) and
# auto-fetches imagery from Unsplash. Every external call degrades gracefully:
# a failed Unsplash fetch never blocks a save, and the LLM/Unsplash calls are
# fully stubbable in tests so no network is touched there.
class BlogPostAiService
  UNSPLASH_API_URL = "https://api.unsplash.com/photos/random"

  def initialize(user)
    @user = user
  end

  # Creates a brand-new blog post from a user prompt.
  # featured_image: an ActionDispatch::Http::UploadedFile (from a form upload) or nil.
  #   If nil and no image_url is given, Unsplash auto-fetches a feature image.
  # image_url: a fallback image URL supplied by Louis (skips Unsplash when present).
  # status: desired publish state (:draft, :published, :scheduled) — defaults to :draft.
  # scheduled_at: a Time; required when status is :scheduled.
  # Returns the BlogPost instance (persisted on success, unpersisted with errors if not).
  def create_from_prompt(prompt, featured_image: nil, image_url: nil, status: :draft, scheduled_at: nil)
    available_tags = Tag.order(:name).to_a

    response = build_chat(creation_system_prompt(available_tags)).ask(prompt)
    parsed = response.content

    # Replace any <!-- IMAGE: query --> placeholders the AI placed in the content.
    content = inject_inline_images(parsed["content"])

    # Feature image: skip Unsplash if Louis uploaded their own file or gave a URL.
    unsplash = (featured_image.present? || image_url.present?) ? nil : fetch_unsplash_data(parsed["image_query"])
    final_image_url = image_url.presence || unsplash&.fetch(:url)

    blog_post = @user.blog_posts.build(
      title: parsed["title"],
      blog_excerpt: parsed["excerpt"],
      html_content: content,
      img_url: final_image_url,
      featured_image_caption: unsplash ? figcaption_html(unsplash) : nil,
      ai_generated: true,
      status: status,
      scheduled_at: scheduled_at
    )

    blog_post.featured_image.attach(featured_image) if featured_image.present?

    # Assign only IDs the AI picked that actually exist — guards hallucinated IDs.
    blog_post.tag_ids = filter_valid_tag_ids(parsed["tag_ids"], available_tags)

    blog_post.save
    blog_post
  end

  # Revises an existing blog post using the given revision prompt.
  # featured_image: a newly uploaded file, or nil.
  # keep_featured_image: if true, preserve the existing image and skip Unsplash.
  # Priority: new upload > keep flag > new custom URL > fresh Unsplash (default).
  # Returns the BlogPost instance.
  def revise_blog_post(blog_post, revision_prompt, featured_image: nil, image_url: nil,
                       keep_featured_image: false, status: nil, scheduled_at: nil)
    available_tags = Tag.order(:name).to_a

    current_content = if blog_post.html_content.present?
      blog_post.html_content
    elsif blog_post.body.present?
      blog_post.body.to_plain_text
    else
      ""
    end

    response = build_chat(revision_system_prompt(blog_post, current_content, available_tags)).ask(revision_prompt)
    parsed = response.content

    content = inject_inline_images(parsed["content"])

    # A pre-filled URL identical to the stored img_url means "I didn't change the
    # field", so Unsplash should still refresh. Only a genuinely new URL overrides.
    new_custom_url = image_url.present? && image_url != blog_post.img_url

    # Feature image priority: new upload > keep flag > new custom URL > fresh Unsplash.
    unsplash = nil
    if featured_image.present?
      blog_post.featured_image.attach(featured_image)
    elsif keep_featured_image
      # Keep the existing image — leave featured_image, img_url, caption untouched.
    elsif new_custom_url
      blog_post.featured_image.purge_later if blog_post.featured_image.attached?
    else
      # Default: the revision may have changed the topic — fetch a fresh photo and
      # purge any stale attachment so the show page doesn't render an old image.
      blog_post.featured_image.purge_later if blog_post.featured_image.attached?
      unsplash = fetch_unsplash_data(parsed["image_query"])
    end

    final_image_url = if featured_image.present?
      nil # Active Storage attachment takes over; clear img_url.
    elsif keep_featured_image
      blog_post.img_url # preserve unchanged
    elsif new_custom_url
      image_url # Louis's explicit new URL
    else
      unsplash&.fetch(:url) # fresh Unsplash URL (nil if the fetch failed)
    end

    final_caption = if featured_image.present?
      nil
    elsif keep_featured_image
      blog_post.featured_image_caption # preserve unchanged
    elsif new_custom_url
      nil
    else
      unsplash ? figcaption_html(unsplash) : nil
    end

    attrs = {
      title: parsed["title"],
      blog_excerpt: parsed["excerpt"],
      html_content: content,
      img_url: final_image_url,
      featured_image_caption: final_caption,
      ai_generated: true,
      human_generated: true
    }
    if status
      attrs[:status] = status
      attrs[:scheduled_at] = (status == :scheduled ? scheduled_at : nil)
    end
    blog_post.assign_attributes(attrs)

    # Clear the rich-text body — the AI has used it as a reference and this post
    # is now managed via html_content only (one_content_field_only forbids both).
    blog_post.body = nil

    blog_post.tag_ids = filter_valid_tag_ids(parsed["tag_ids"], available_tags)

    blog_post.save
    blog_post
  end

  private

  # Builds a Claude chat with the system prompt and structured-output schema.
  # provider: :anthropic + assume_model_exists: true so a newer model id (valid
  # but absent from the gem's registry) doesn't raise ModelNotFoundError.
  def build_chat(system_prompt)
    chat = RubyLLM.chat(
      model: ENV.fetch("AI_MODEL", "claude-sonnet-5"),
      provider: :anthropic,
      assume_model_exists: true
    )
    chat.with_instructions(system_prompt).with_schema(BlogPostSchema)
  end

  # Replaces <!-- IMAGE: search query --> placeholders in AI-generated HTML with
  # real Unsplash figures. Leaves an empty string if the fetch fails.
  def inject_inline_images(content)
    content.to_s.gsub(/<!-- IMAGE: (.+?) -->/) do
      query = ::Regexp.last_match(1).strip
      fetch_image_html(query)
    end
  end

  # Fetches Unsplash metadata for a featured image.
  # Returns { url:, photographer:, photographer_url:, photo_url: } or nil on any failure.
  def fetch_unsplash_data(query)
    access_key = ENV.fetch("UNSPLASH_ACCESS_KEY", nil)
    return nil if access_key.blank? || query.blank?

    uri = URI(UNSPLASH_API_URL)
    uri.query = URI.encode_www_form(query: query, orientation: "landscape", client_id: access_key)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get(uri.request_uri)
    end
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    url = data.dig("urls", "regular")
    return nil if url.blank?

    {
      url: url,
      photographer: data.dig("user", "name"),
      photographer_url: "#{data.dig("user", "links", "html")}?utm_source=louisb_portfolio&utm_medium=referral",
      photo_url: "#{data.dig("links", "html")}?utm_source=louisb_portfolio&utm_medium=referral"
    }
  rescue StandardError => e
    Rails.logger.warn "Unsplash featured image fetch failed: #{e.message}"
    nil
  end

  # Returns a <figcaption> string for an Unsplash photo (stored in
  # featured_image_caption and rendered directly below the featured image).
  def figcaption_html(data)
    "<figcaption class='text-muted mt-1' style='font-size:0.8em;'>" \
      "Photo by <a href='#{data[:photographer_url]}'>#{data[:photographer]}</a> on " \
      "<a href='#{data[:photo_url]}'>Unsplash</a>" \
      "</figcaption>"
  end

  # Fetches a relevant Unsplash photo and returns a ready-to-inject <figure> HTML
  # string for inline <!-- IMAGE: query --> placeholders. Returns "" when the key
  # is missing or the request fails — a failed image fetch never blocks a save.
  def fetch_image_html(query)
    access_key = ENV.fetch("UNSPLASH_ACCESS_KEY", nil)
    return "" if access_key.blank? || query.blank?

    uri = URI(UNSPLASH_API_URL)
    uri.query = URI.encode_www_form(query: query, orientation: "landscape", client_id: access_key)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get(uri.request_uri)
    end
    return "" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    image_url        = data.dig("urls", "regular")
    photographer     = data.dig("user", "name")
    photographer_url = "#{data.dig("user", "links", "html")}?utm_source=louisb_portfolio&utm_medium=referral"
    photo_url        = "#{data.dig("links", "html")}?utm_source=louisb_portfolio&utm_medium=referral"

    return "" if image_url.blank?

    # Unsplash terms require attribution — photographer name + Unsplash link.
    "<figure class='mb-4'>" \
      "<img src='#{image_url}' alt='#{query}' class='img-fluid rounded' style='width:100%;max-height:420px;object-fit:cover;'>" \
      "<figcaption class='text-muted mt-1' style='font-size:0.8em;'>" \
        "Photo by <a href='#{photographer_url}'>#{photographer}</a> on " \
        "<a href='#{photo_url}'>Unsplash</a>" \
      "</figcaption>" \
    "</figure>"
  rescue StandardError => e
    Rails.logger.warn "Unsplash image fetch failed: #{e.message}"
    ""
  end

  # Returns only IDs from the AI's response that exist in the available tag list,
  # preventing hallucinated IDs from creating unexpected associations.
  def filter_valid_tag_ids(ai_ids, available_tags)
    return [] if ai_ids.blank?

    valid_ids = available_tags.map(&:id).to_set
    Array(ai_ids).map(&:to_i).select { |id| valid_ids.include?(id) }
  end

  def creation_system_prompt(available_tags)
    <<~PROMPT
      ## Persona
      You are an expert technical writer and web developer helping Louis Bourne write posts for his
      personal developer portfolio blog. Louis is a developer with a background in trading and financial
      analysis, writing about web development (Ruby on Rails, JavaScript, TypeScript), deployment, and
      lessons learned while building projects.

      ## Context
      You are writing a blog post for Louis's portfolio website. The audience is fellow developers and
      technically-minded readers. The site is styled with Bootstrap 5 — use only generic Bootstrap utility
      classes for any styling (do NOT hardcode colours or a theme; the site's own CSS handles appearance).

      ## Task
      Write a full blog post based on the topic provided. The tone is practical and approachable — explain
      jargon where used, and write in the first person where it feels natural ("When I deployed...",
      "I found that..."). Target length: 400–700 words of content (excluding the title).

      ## Format
      Return five fields: `title`, `excerpt`, `content`, `image_query`, and `tag_ids`.

      **`excerpt`**: A 1-2 sentence plain-text summary (no HTML). Shown as the preview card on the blog
      index. Keep it under 180 characters — informative and compelling.

      **`image_query`**: A short 2–4 word Unsplash search query for a relevant header image. Prefer
      landscapes, technology, code, or workspace imagery (e.g. "code on screen", "developer desk",
      "server room"). Avoid people-focused or abstract queries.

      **`content`**: The full blog post as a plain HTML string — no JSON, no Markdown, no code fences.
      Follow these rules exactly:
      1. Use single quotes for all HTML attribute values (e.g. class='...' not class="...")
      2. Escape any apostrophes inside attribute values with a backslash (e.g. data-label='it\\'s')
      3. Do NOT include the title — the `title` field handles that separately
      4. Do NOT wrap content in <html>, <body>, <head>, <article>, or <div class='container'> — your
         content is already injected inside the page's article container
      5. Start the post body with an <h2> tag — <h1> is already used for the page title
      6. Use semantic HTML: h2, h3, p, ul, ol, li, blockquote, code
      7. For <code> blocks add a subtle border and light background using inline styles
         (e.g. style='background:#f3f4f6;border:1px solid #d1d5db;border-radius:4px;padding:2px 6px;')
      8. Prefer Bootstrap utility classes for styling (e.g. class='text-muted' for secondary text,
         class='fw-bold' for bold). Use inline styles only when no suitable Bootstrap class exists —
         do NOT add custom font-family styles and do NOT hardcode a colour theme
      9. You may use bold, italic, and underline where it adds meaning
      10. Remove any numbered citations in brackets (e.g. [1], [2])
      11. No <script> or <style> elements
      12. No target='_blank' attributes — these may be sanitized
      13. Optimize for SEO: use relevant keywords naturally in headings and the opening paragraph
      14. Return the HTML as a single unformatted string with no line breaks between tags
      15. You may insert up to 2 inline image placeholders using the syntax: <!-- IMAGE: your query here -->
         — place them between sections where a relevant photo adds value. Use 2–4 word Unsplash-style
         queries (e.g. <!-- IMAGE: terminal window code -->). They are automatically replaced with real
         Unsplash photos. Do not use this for the header image — that is handled separately.

      ## Tags
      #{tag_list_prompt(available_tags)}
    PROMPT
  end

  def revision_system_prompt(blog_post, current_content, available_tags)
    <<~PROMPT
      ## Persona
      You are an expert technical writer and web developer helping Louis Bourne revise posts for his
      personal developer portfolio blog.

      ## Context
      You are revising an existing blog post on Louis's portfolio website. The site is styled with
      Bootstrap 5 — use only generic Bootstrap utility classes for any styling (do NOT hardcode colours
      or a theme).

      The current post to revise is:

      TITLE: #{blog_post.title}

      CURRENT CONTENT:
      #{current_content}

      ---

      ## Task
      Revise this blog post based on Louis's instructions. Preserve the overall structure and tone unless
      explicitly told to change them. Return the revised `title`, a revised `excerpt`, the full revised
      `content`, a fresh `image_query`, and relevant `tag_ids`.

      ## Format
      Return five fields: `title`, `excerpt`, `content`, `image_query`, and `tag_ids`.

      **`excerpt`**: A 1-2 sentence plain-text summary (no HTML). Shown as the preview card on the blog
      index. Keep it under 180 characters — informative and compelling.

      **`image_query`**: A short 2–4 word Unsplash search query for a relevant header image. Prefer
      landscapes, technology, code, or workspace imagery. Avoid people-focused or abstract queries.

      **`content`**: The full revised blog post as a plain HTML string — no JSON, no Markdown, no code
      fences. Follow these rules exactly:
      1. Use single quotes for all HTML attribute values (e.g. class='...' not class="...")
      2. Escape any apostrophes inside attribute values with a backslash (e.g. data-label='it\\'s')
      3. Do NOT include the title — the `title` field handles that separately
      4. Do NOT wrap content in <html>, <body>, <head>, <article>, or <div class='container'>
      5. Start the post body with an <h2> tag — <h1> is already used for the page title
      6. Use semantic HTML: h2, h3, p, ul, ol, li, blockquote, code
      7. For <code> blocks add a subtle border and light background using inline styles
         (e.g. style='background:#f3f4f6;border:1px solid #d1d5db;border-radius:4px;padding:2px 6px;')
      8. Prefer Bootstrap utility classes for styling. Use inline styles only when no suitable Bootstrap
         class exists — do NOT add custom font-family styles and do NOT hardcode a colour theme
      9. You may use bold, italic, and underline where it adds meaning
      10. Remove any numbered citations in brackets (e.g. [1], [2])
      11. No <script> or <style> elements
      12. No target='_blank' attributes — these may be sanitized
      13. Optimize for SEO: use relevant keywords naturally in headings and the opening paragraph
      14. Return the HTML as a single unformatted string with no line breaks between tags
      15. You may insert up to 2 inline image placeholders using the syntax: <!-- IMAGE: your query here -->
         — they are automatically replaced with real Unsplash photos. Do not use this for the header image.

      ## Tags
      #{tag_list_prompt(available_tags)}
    PROMPT
  end

  # Builds the tag instruction block injected into both system prompts.
  def tag_list_prompt(available_tags)
    if available_tags.empty?
      "No tags have been created yet. Return an empty array for `tag_ids`."
    else
      tag_lines = available_tags.map { |t| "- ID #{t.id}: #{t.name}" }.join("\n")
      <<~TEXT
        The following tags exist on this blog. Select only those genuinely relevant to the post topic.
        Return their IDs in the `tag_ids` field. Return an empty array if none apply. Do NOT invent or
        guess IDs not listed below.

        #{tag_lines}
      TEXT
    end
  end
end
