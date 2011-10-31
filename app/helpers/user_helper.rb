# Methods for creating links.
module UserHelper
  
  def link_to_file_of_device(text, deviceid, filepath)
    link_to text, :controller=> "devfile", :action=>"getfile", :filepath=>filepath, :deviceid=>deviceid
  end
 
  #def link_to_files_of_device(deviceid)
  #  url_for :controller=> "query", :action=>"get", :deviceid=>deviceid, :what_to_get => 'files', :format=>"atom", :skip_relative_url_root=>true
  #end
  
  def link_to_add_new_group(text)
    link_to text, :controller => "user", :action => "addGroup"
  end
  
  def linkt_to_edit_user_groups(text, username, user_id)
    link_to text, :controller => "user", :username => username, :action => "editUserGroups", :user_id => user_id
  end
  
  def link_to_API(text)
    link_to text, :controller => 'user', :action=> 'doc', :filepath => 'index.html'
  end
  
  # ei toimi controllerissa :(
  #def link_to_files_of_device(linktext, devicename, username)
  #  link_to linktext, :controller => 'query', :action => 'get', :username => username, :devicename => devicename, :what_to_get => 'files'
  #end
  
end
