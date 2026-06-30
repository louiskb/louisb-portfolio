# frozen_string_literal: true

# Pagy initializer (43.x)
# See https://ddnexus.github.io/pagy/resources/initializer/

############ Global Options ################################################################
# 9 per page = a 3-column grid × 3 rows on the blog index.
Pagy::OPTIONS[:limit] = 9

Pagy::OPTIONS.freeze
