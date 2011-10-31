class FileObserver < ActiveRecord::Base
  belongs_to :devfile
  
  belongs_to :user
  
  
  #validates_uniqueness_of :devfile_id, :scope => [:user_id, :devfile_id], :on => :create
end
