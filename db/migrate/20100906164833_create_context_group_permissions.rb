class CreateContextGroupPermissions < ActiveRecord::Migration
  def self.up
    create_table :context_group_permissions do |t|
      t.integer :group_id
      t.integer :context_id


    end
  end

  def self.down
    drop_table :context_group_permissions
  end
end
