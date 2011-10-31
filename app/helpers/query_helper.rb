# Methods for creating links.
module QueryHelper
  def devfile_url(file)
     url = "/user/" + @user + "/device/" + @dev + "/files" + file.path + file.name
     return url
  end
  
  def blob_url(file)
     url = "/user/" + file.username + "/device/" + file.dev_name + "/files" + file.path + file.name + "?version=" + file.version.to_s
     return url
  end
  
  def versionlist_url(file)
     url = "/user/" + file.username + "/device/" + file.dev_name + "/fileversions" + file.path + file.name + "?format=atom"
     return url
  end
  
  def link_to_file_of_device(text, deviceid, filepath)
    link_to text, :controller=> "devfile", :action=>"getfile", :filepath=>filepath, :deviceid=>deviceid
  end
 
  def link_to_files_of_device(deviceid)
    url_for :controller=> "query", :action=>"get", :deviceid=>deviceid, :what_to_get => 'files', :format=>"atom", :skip_relative_url_root=>true
  end
 
end
