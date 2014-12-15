class ChangeIssueCategoriesNameLengthTo70 < ActiveRecord::Migration
  def up
    change_column :issue_categories, :name, :string, :limit => 70, :default => '', :null => false
  end

  def down
    change_column :issue_categories, :name, :string, :limit => 30, :default => '', :null => false
  end
end
