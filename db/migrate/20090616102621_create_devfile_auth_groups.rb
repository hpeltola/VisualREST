class CreateDevfileAuthGroups < ActiveRecord::Migration
  def self.up
    create_table :devfile_auth_groups, :id => false do |t|
      t.integer :devfile_id
      t.integer :group_id

      t.timestamps
    end
  end

  def self.down
    drop_table :devfile_auth_groups
  end
end
