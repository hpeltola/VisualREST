# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION



# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|


  if RUBY_VERSION =~ /1.9/
      Encoding.default_external = Encoding::UTF_8
      Encoding.default_internal = Encoding::UTF_8
  end


  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Specify gems that this application depends on and have them installed with rake gems:install
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "sqlite3-ruby", :lib => "sqlite3"
  # config.gem "aws-s3", :lib => "aws/s3"

  # Only load the plugins named here, in the order given (default is alphabetical).
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Skip frameworks you're not going to use. To use Rails without a database,
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

  # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
  # Run "rake -D time" for a list of tasks for finding time zone names.
  #config.time_zone = 'UTC'
  
  config.action_controller.session = {
    :session_key => 'ses_id',
    :secret      => 'secretpass'
  }
  
  config.action_controller.session_store = :active_record_store

  # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
  # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
  # config.i18n.default_locale = :de
  

end

  
  require 'rubygems'
  require 'xml/libxml'
  require 'mime/types'
  require 'xmpp4r'
#  require 'ftools'
  require 'will_paginate'
  require 'fileutils'
  require 'timeout'
  require 'rainbow'
  
  require 'grit'
  include Grit
  
 # require 'gd2'
  #require 'gd2-ffij'
 # include GD2
  
  require 'json'
  
  
  
  require 'hmac-sha1'
  require 'digest/sha1'
  require 'base64'

  require 'RMagick'
  include Magick
  
  
  
  
  
  require "xmpp4r/pubsub"
  require "xmpp4r/pubsub/helper/servicehelper.rb"
  require "xmpp4r/pubsub/helper/nodebrowser.rb"
  require "xmpp4r/pubsub/helper/nodehelper.rb"
  
  require "./lib/save_to_virtual_container.rb"
  
  require "./lib/XmppHelper.rb"
  require "./lib/NodeHelper.rb"
  require "./lib/HttpHelper.rb"
  require "./lib/DropboxHelper.rb"
  require "./lib/CollageHelper.rb"

  require "./lib/ContentHelper.rb"
  require "./lib/CommitManager.rb"
  require "./lib/VirtualContainerManager.rb"
  
  require "./lib/DeleteHelper.rb"

  require "./lib/MetadataHelper.rb"

  require "./lib/ContentObject.rb"
  require "./lib/ClusterObject.rb"
  require "./lib/ContextObject.rb"