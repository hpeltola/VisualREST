class AddNickToNodes < ActiveRecord::Migration
  def self.up
    add_column :nodes, :nick_name, :string
  end

  def self.down
    remove_column :nodes, :nick_name
  end
end
