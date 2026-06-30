# Extend Rails' default sanitize allowlist to support the HTML elements and
# attributes used by AI-generated blog post content and Unsplash attribution
# figures. Note: `style` is an ATTRIBUTE (not a tag).
Rails::HTML5::SafeListSanitizer.allowed_tags += %w[figure figcaption]
Rails::HTML5::SafeListSanitizer.allowed_attributes += %w[style]
