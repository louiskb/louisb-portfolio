# Shared publishing behaviour for content models (BlogPost, Project).
#
# Provides a three-state `status` enum (draft / scheduled / published), a
# `visible_to_visitors` scope (public-facing records only), and small intent
# helpers used by the scheduled-publishing flow.
#
# Records default to `published` (column default 2) so existing content stays
# visible after the migration.
module Publishable
  extend ActiveSupport::Concern

  included do
    enum :status, { draft: 0, scheduled: 1, published: 2 }

    # Records a visitor (signed-out) is allowed to see.
    scope :visible_to_visitors, -> { where(status: :published) }
  end

  # Publish immediately and clear any pending schedule.
  def publish!
    update!(status: :published, scheduled_at: nil)
  end

  # Schedule the record to be published at `time` (a future Time).
  def schedule!(time)
    update!(status: :scheduled, scheduled_at: time)
  end

  # Revert a scheduled/published record back to a draft.
  def cancel_schedule!
    update!(status: :draft, scheduled_at: nil)
  end
end
