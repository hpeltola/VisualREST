class AddPubsubNodesToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :user_psnode, :string
  end

  def self.down
    remove_column :users, :user_psnode
  end
end
