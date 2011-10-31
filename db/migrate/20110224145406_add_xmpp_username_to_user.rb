class AddXmppUsernameToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :xmpp_jid, :string
    add_column :users, :xmpp_host, :string
  end

  def self.down
    remove_column :users, :xmpp_host
    remove_column :users, :xmpp_jid
  end
end
