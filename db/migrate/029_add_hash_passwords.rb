require 'bcrypt'

class AddHashPasswords < ActiveRecord::Migration
  def self.up
    add_column :users, :hashed_password, :string, :limit => 60
    add_column :users, :password_reset_key, :string, :limit => 60

    User.reset_column_information

    User.all.each do |user|
      puts user.email
      puts user.is_local_user?
      puts user.password
      if not user.is_local_user?:
        # Copy the old db column into the new in-memory unhashed version of the password
        user.unhashed_password = user.password
        user.hash_password
        user.save()
      end
      puts user.hashed_password
    end
    #remove_column :users, :password
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration, "Can't unhash passwords"
  end
end
