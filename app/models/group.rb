# Object of this class is used to describe certain group. Group has information about the owner
# of the group (id) and it has name. User can only have one group with ceratain name. The purpose of
# this class is to collect users together and then give goups access to certain files.
#
#   Belongs to one certain user.
#   Has many usersingroups.
#   Has many users through usersingroups.
#
class Group < ActiveRecord::Base
  belongs_to :user
  has_many :usersingroups
  has_many :users, :through => :usersingroups
  
  has_many :context_group_permissions
  has_many :contexts, :through => :context_group_permissions

  # min and max length of groupname
  NAME_MIN_LENGTH = 2 
  NAME_MAX_LENGTH = 40 
  
  NAME_RANGE = NAME_MIN_LENGTH..NAME_MAX_LENGTH

  # textbox size (in views)
  NAME_SIZE = 20
  
  
  #validates_uniqueness_of :name, :scope => "user_id", :on => :create
  
  
  #validates_length_of :name, :within => NAME_RANGE, :on => :create
  
  validates_format_of :name,
                      :with => /\w{1,}/, 
                      :message => "must contain only letters, " + 
                                  "numbers, and underscores", 
                      :on => :create
  
end
