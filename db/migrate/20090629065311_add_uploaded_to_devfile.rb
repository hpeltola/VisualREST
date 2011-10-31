class AddUploadedToDevfile < ActiveRecord::Migration
  def self.up
    add_column :devfiles, :uploaded, :boolean
  end

  def self.down
    remove_column :devfiles, :uploaded
  end
end
