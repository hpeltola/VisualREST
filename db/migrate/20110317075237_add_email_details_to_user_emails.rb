class AddEmailDetailsToUserEmails < ActiveRecord::Migration
  def self.up
    add_column :user_emails, :mail_username, :string
    add_column :user_emails, :mail_password, :string
    add_column :user_emails, :mail_server, :string
    add_column :user_emails, :mail_port, :integer
    add_column :user_emails, :mail_checking, :boolean
    add_column :user_emails, :last_uid, :integer
  end

  def self.down
    remove_column :user_emails, :mail_username
    remove_column :user_emails, :mail_password
    remove_column :user_emails, :mail_server
    remove_column :user_emails, :mail_port
    remove_column :user_emails, :mail_checking
    remove_column :user_emails, :last_uid
  end
end
