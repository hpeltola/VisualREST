# Methods for creating links.
module DevfileHelper
  def link_files_of_device(file)
    if file.path != "/"
      url_for( :controller => 'devfile',
                            :action => 'getfile',
                            :username => h(@fileowner),
                            :devicename => h(file.device.dev_name),
                            :filepath => (file.path.to_s + file.name)[1..-1]).gsub!("%2F", "/")
    else
      url_for :controller => 'devfile',
                            :action => 'getfile',
                            :username => h(@fileowner),
                            :devicename => h(file.device.dev_name),
                            :filename => h(file.name)
    end
  end
  
  

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

  
  
end
