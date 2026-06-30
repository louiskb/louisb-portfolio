class BackfillSlugsForProjectsAndBlogPosts < ActiveRecord::Migration[8.1]
  # Backfill slugs for legacy rows. Uses `update_columns` (direct SQL, no
  # validations/callbacks) so invalid legacy rows are never silently skipped,
  # and reproduces FriendlyId's default normalization (`title.parameterize`).
  def up
    backfill(Project)
    backfill(BlogPost)
  end

  def down
    Project.where.not(slug: nil).update_all(slug: nil)
    BlogPost.where.not(slug: nil).update_all(slug: nil)
  end

  private

  def backfill(klass)
    klass.reset_column_information
    used = klass.where.not(slug: [ nil, "" ]).pluck(:slug).to_set

    klass.where(slug: [ nil, "" ]).find_each do |record|
      base = record.title.to_s.parameterize
      base = klass.name.underscore if base.blank?
      candidate = base
      counter = 1
      while used.include?(candidate)
        counter += 1
        candidate = "#{base}-#{counter}"
      end
      used << candidate
      record.update_columns(slug: candidate)
    end
  end
end
