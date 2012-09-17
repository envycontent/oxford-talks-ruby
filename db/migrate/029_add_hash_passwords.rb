class AddHashPasswords < ActiveRecord::Migration
  def self.up
    add_column :users, :hashed_password, :string, :limit => 60
    add_column :users, :password_reset_key, :string, :limit => 60
    remove_column :users, :password
  end

  def self.down
    add_column :users, :password, :string, :limit => 50
    remove_column :users, :password_reset_key
    remove_column :users, :hashed_password
  end
end
