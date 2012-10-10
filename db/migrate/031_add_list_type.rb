class AddListType < ActiveRecord::Migration
  def self.up
    add_column :lists, :list_type, :string, :limit => 60
  end

  def self.down
    remove_column :lists, :list_type
  end
end
