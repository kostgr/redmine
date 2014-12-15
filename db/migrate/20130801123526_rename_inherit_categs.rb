class RenameInheritCategs < ActiveRecord::Migration
  def change
    rename_column :projects, :inherit, :inherit_categs
  end
end
