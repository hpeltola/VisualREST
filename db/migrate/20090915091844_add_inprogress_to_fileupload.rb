class AddInprogressToFileupload < ActiveRecord::Migration
  def self.up
    add_column :fileuploads, :inprogress, :boolean
  end

  def self.down
    remove_column :fileuploads, :inprogress
  end
end
