class AddPrivateToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :private, :boolean
  end
end
