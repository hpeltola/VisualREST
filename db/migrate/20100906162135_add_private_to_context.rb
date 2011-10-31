class AddPrivateToContext < ActiveRecord::Migration
  def self.up
    add_column :contexts, :private, :boolean
  end

  def self.down
    remove_column :contexts, :private
  end
end
