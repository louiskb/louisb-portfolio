# BlogPostSchema — structured-output schema for the AI blog post service.
#
# ruby_llm 1.16 no longer ships a RubyLLM::Schema base class. `with_schema`
# instantiates this class and calls `to_json_schema` on the instance, then
# passes the returned Hash to the provider (Anthropic) which enforces it and
# returns an already-parsed Hash in `response.content`.
class BlogPostSchema
  def to_json_schema
    {
      name: "blog_post",
      description: "A structured technical blog post with a title, excerpt, HTML content, and an image search query",
      schema: {
        type: "object",
        properties: {
          title: {
            type: "string",
            description: "A clear, engaging blog post title"
          },
          excerpt: {
            type: "string",
            description: "A 1-2 sentence plain-text summary of the post (no HTML). Shown as the preview on the blog index page. Keep it under 180 characters — compelling but concise."
          },
          content: {
            type: "string",
            description: "The full blog post content as semantic HTML. Use h2 and h3 for section headings, p for paragraphs, ul/ol/li for lists, blockquote for quotes. Do not include a wrapping html/body tag — content only."
          },
          image_query: {
            type: "string",
            description: "A short, descriptive Unsplash search query (2-4 words) to find a relevant header image. E.g. 'software developer desk', 'code on screen', 'mountain landscape'. Avoid abstract or people-focused queries — prefer landscapes, technology, and workspace environments."
          },
          tag_ids: {
            type: "array",
            items: { type: "integer" },
            description: "IDs of pre-existing tags that are relevant to this post. Choose only from the list provided in the system prompt. Return an empty array if none apply. Do NOT invent IDs that were not in the list."
          }
        },
        required: ["title", "excerpt", "content", "image_query", "tag_ids"],
        additionalProperties: false
      }
    }
  end
end
