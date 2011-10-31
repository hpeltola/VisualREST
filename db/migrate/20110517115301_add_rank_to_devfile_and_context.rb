class AddRankToDevfileAndContext < ActiveRecord::Migration
  def self.up
    add_column :devfiles, :rank, :integer, :default => 0
    add_column :devfiles, :deleted, :boolean, :default => 0
    add_column :contexts, :rank, :integer, :default => 0
  end

  def self.down
    remove_column :devfiles, :rank
    remove_column :devfiles, :deleted
    remove_column :contexts, :rank
  end
end
