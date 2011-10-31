class AddFiledateToDevfile < ActiveRecord::Migration
  def self.up
    add_column :devfiles, :filedate, :datetime
  end

  def self.down
    remove_column :devfiles, :filedate
  end
end
