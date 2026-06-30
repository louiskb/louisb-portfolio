class AddPublishingColumnsToProjects < ActiveRecord::Migration[8.1]
  def up
    add_column :projects, :slug, :string
    add_column :projects, :status, :integer, default: 2, null: false
    add_column :projects, :scheduled_at, :datetime
    add_column :projects, :position, :integer

    add_index :projects, :slug, unique: true

    # Backfill position deterministically by creation order (0-based to match the
    # reorder action's each_with_index assignment).
    execute <<~SQL.squish
      UPDATE projects
      SET position = sub.rn - 1
      FROM (
        SELECT id, ROW_NUMBER() OVER (ORDER BY created_at, id) AS rn
        FROM projects
      ) sub
      WHERE projects.id = sub.id
    SQL
  end

  def down
    remove_index :projects, :slug
    remove_column :projects, :position
    remove_column :projects, :scheduled_at
    remove_column :projects, :status
    remove_column :projects, :slug
  end
end
