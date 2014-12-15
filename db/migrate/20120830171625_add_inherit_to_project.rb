class AddInheritToProject < ActiveRecord::Migration
  def change
    add_column :projects, :inherit, :boolean
  end
end
