class AddPrivatefileToDevfile < ActiveRecord::Migration
  def self.up
    add_column :devfiles, :privatefile, :boolean
  end

  def self.down
    remove_column :devfiles, :privatefile
  end
end
