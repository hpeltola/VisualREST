class AddXmppPwToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :xmpp_pw, :string
  end

  def self.down
    remove_column :users, :xmpp_pw
  end
end
