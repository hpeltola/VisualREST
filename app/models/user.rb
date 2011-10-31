# Object of this class is used to describe certain user. Object has informations about user's real name
# username and password. User's username is unique and user has also unique id.
#
#   Has many devices and usersingroups.
#   Has many groups through usersingroups.
#
class User < ActiveRecord::Base
  #has_many :groups
  has_many :devices
  has_many :usersingroups
  has_many :groups, :through => :usersingroups # the ones that user is a member of (not owner)
  has_many :context_names
  
  # Users can own many contexts
  has_many :contexts
  
  has_many :nodes
  
  has_many :service_informations
  
  
  # Max & min lengths for all fields 
  REAL_NAME_MIN_LENGTH = 4 
  REAL_NAME_MAX_LENGTH = 20 
  
  PASSWORD_MIN_LENGTH = 4 
  PASSWORD_MAX_LENGTH = 40 
  
  USERNAME_MIN_LENGTH = 6
  USERNAME_MAX_LENGTH = 50 
  
  REAL_NAME_RANGE = REAL_NAME_MIN_LENGTH..REAL_NAME_MAX_LENGTH 
  PASSWORD_RANGE = PASSWORD_MIN_LENGTH..PASSWORD_MAX_LENGTH 
  USERNAME_RANGE = USERNAME_MIN_LENGTH..USERNAME_MAX_LENGTH

  # Text box sizes for display in the views 
  REAL_NAME_SIZE = 20 
  PASSWORD_SIZE = 20 
  USERNAME_SIZE = 20

  validates_uniqueness_of :username 
  validates_length_of :real_name, :within => REAL_NAME_RANGE
  validates_length_of :password, :within => PASSWORD_RANGE 
  validates_length_of :username, :maximum => USERNAME_MAX_LENGTH 
  
  validates_format_of :real_name, 
                      :with => /.{1,}/, 
                      :message => "must contain only letters, " + 
                                  "numbers, and underscores" 
#  validates_format_of :username, 
#                      :with => /^[A-Z0-9._%-]+@([A-Z0-9-]+\.)+[A-Z]{2,4}$/i, 
#                      :message => "must be a valid email address"
  
  validates_format_of :username, 
                      :with => /\w{1,20}/, 
                      :message => "must contain only letters, numbers and underscores"





end
