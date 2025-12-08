class RenamePrivateToPrivateRepoInProjects < ActiveRecord::Migration[7.1]
  def change
    rename_column :projects, :private, :private_repo
  end
end
