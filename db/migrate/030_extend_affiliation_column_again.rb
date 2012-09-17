class ExtendAffiliationColumnAgain < ActiveRecord::Migration
  def self.up
    change_column :users, :affiliation, :string, :limit => 200
  end

  def self.down
    change_column :users, :affiliation, :string, :limit => 75
  end
end
