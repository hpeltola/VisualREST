require 'grit'



# Class that controls file-related matters. File viewing, uploading, deleting, file rights etc.
class DevfileController < ApplicationController

  # Protection from cross site request forgery
  protect_from_forgery :except => [:upload, :requestUploadtest, :isUploadReady, 
                                    :deleteFile, :editRights, :changeMetadata, :deleteMetadata]

  # These methods need authentication:
  before_filter :authenticate, :only => [:deleteFile, :upload, :beginUpload, :editRights]
  before_filter :authenticateFile, :only => [:getfile, :getMetadatas]
  
  # This is a temporary function, intended for adding metadatatype - backup_recovery_path
  #                                                   metadatavalue - /home/user/MyDocs/DCIM/<filename>
  #     to all files of the system
  def temp
    # Find all files in the system
    allFiles = Devfile.find(:all)
    
    metadatatype = MetadataType.find_by_name("backup_recovery_path")
    if metadatatype == nil
      render :text => "Metadatatype was not found", :status => 404
      return
    end
    
    # Go through each file and add metadata to it
    allFiles.each do |x|
      metadatavalue = '/home/user/MyDocs/DCIM/'+x.name
      Metadata.find_or_create_by_metadata_type_id_and_devfile_id(:metadata_type_id => metadatatype.id,
                                                                 :value => metadatavalue,
                                                                 :devfile_id => x.id)      
    end
    
    render :text => "Metadata added to all files in the system", :status => 201
    return
  end
  
  
  
  def test
    
    XmppHelper::sendXmppMessage("ps_niko_1@nota.cs.tut.fi", "viesti")
    
    render :text => "testi", :status => 200
    return
  end
  
  
  # Gets metadatas of a certain file. 
  # 
  # Paramaters: With format parameter it is possible to get the metadatas in yml format as well.
  #
  # Usage:
  #   Send GET to /user/{username}/device/{devicename}/metadatas/{filepath}/*version [Current]
  def getMetadatas
    
    # host parameter, needed when creating atom-feed
    brp = BlobRepresentation.new(@blob.id)
    @results = []
    @results << brp
    @metadatas = []
    @metadatas[brp.devfile_id] = brp.metadatas
    puts
    puts brp.metadatas
    puts
    @metadatatypes = MetadataType.find(:all, :order => "name ASC" )
    
    @host = @@http_host
    respond_to do |format|
      if params[:format] == nil
        format.html {render :getfile, :layout=>true}
      else
        format.html {render :getfile, :layout=>true}      
        format.atom {render :getfile, :layout=>false }
        format.yaml {render :text => YAML.dump_stream(brp.to_yaml).to_s, :status => 200, :layout=>false }
      end
    end
    return
  end
  
  # Get single file
  #
  # Parameters: Filepath (path+filename) and host-device of the file must be specified in
  # the url (either by deviceid or username+devicename).
  # Version is optional. If version is not given, tries to get the newest version of the file.
  #
  # If the given/newest version of the file has previously been uploaded to the server, 
  # the file is immediately shown. If the file has not been uploaded, method tries to get the file 
  # from the client by sending an xmpp-message so that the client would imediately upload 
  # the given version of the file to the server. If the client is online and xmpp-message has been sent, 
  # waits for that the client finally gets the file uploaded. If the file cannot be uploaded for some reason,
  # gives an error message. If the given version of the file cannot be found, generates a list of the possible 
  # versions of the file. The uploading is done with in co-operation with the online method. The online method
  # tells to the server when client is uploading file, and when the uploading is finished. Finally, when the 
  # file has been uploaded, it is returned for the requester in the same http request's response. 
  # Also http response code is returned.
  #
  # Usage: 
  #   Send GET to /user/{username}/device/{devicename}/essence/{filepath}/*version
  def getfile
  puts "getfile"
    # authenticateFile was called before this function
    
    # Increase files rank by 1
    begin
      new_rank = @devfile.rank + 1
      @devfile.update_attribute(:rank, new_rank)
    rescue => e
      puts "Tried to increase rank value for devfile -> failed miserably!"
    end
    
    # The file was public or requester had permission for it.
    # Checks that if the wanted version is already uploaded. 
    if @blob.uploaded != true
      
      # tell the device to upload the file
      trycount = 0
      sendUploadRequest(true)
      sleep(1)
      
      # wait for the upload to begin
      ActiveRecord::Base.connection.clear_query_cache()
      
      # fileupload tells when the uploading is in operation
      fileupload = @blob.fileuploads.find( :first, :conditions => ['end_time is NULL'])
      @devfile = @device.devfiles.find(:first, :conditions => ['name = ? and path = ?', @filename, @path])
      @blob = @devfile.blobs.find(:first, :conditions => ['version = ?', @blob.version])
      # Tries six times at maximum to check that uploading has began
      while fileupload == nil and @blob.uploaded == false and trycount <= 6
        trycount = trycount+1
        sendUploadRequest(true) if trycount == 3
        sleep(2)
        
        # Updating the uplad information from database
        ActiveRecord::Base.connection.clear_query_cache()
        fileupload = @blob.fileuploads.find( :first, :conditions => ['end_time is NULL'])
        @devfile = @device.devfiles.find(:first, :conditions => ['name = ? and path = ?', @filename, @path])
        @blob = @devfile.blobs.find(:first, :conditions => ['version = ?', @blob.version])
      end
      
      # still no response from device
      if fileupload == nil and @blob.uploaded != true
        render :text => "The file has not been uploaded, and the device is not responding. You may try again later.", :status => 503
        return
      end
      
      
      # too large file
      if @blob.size > 10 * 1000 * 1000
        render :text => "The file size is larger than 10mb (" + (@blob.size / 1000000).to_s + "mb). You may check back later.", :status => 413
        return
      end
      # wait for the upload to complete
      sleeptime = 2
      ActiveRecord::Base.connection.clear_query_cache()
      @devfile = @device.devfiles.find(:first, :conditions => ['name = ? and path = ?', @filename, @path])
      @blob = @devfile.blobs.find(:first, :conditions => ['version = ?', @blob.version])
      while !@blob.uploaded
        sleep(sleeptime)
        sleeptime += 1 if sleeptime < 10
        ActiveRecord::Base.connection.clear_query_cache() 
        @devfile = @device.devfiles.find(:first, :conditions => ['name = ? and path = ?', @filename, @path])
        @blob = @devfile.blobs.find(:first, :conditions => ['version = ?', @blob.version])
      end
      
      # send the file by using test_meta_worker's send_data method.
      sendfile = File.open("public/devfiles/" + @devfile.device_id.to_s + "/" + @blob.blob_hash + "_" + @devfile.name, "rb").read
      send_data(sendfile, :type => @devfile.filetype,
                :filename => @devfile.name,
                :disposition => 'inline')
      return
      
    else
      
      # If file in virtual_container -> Get the file from local git
      if @devfile.device.dev_type == "virtual_container"
        begin
          
          # Make sure device has git-repository
          if not File.exists?("private/#{@devfile.device.id}/.git")
            render :text => "Repository for this virtual device was not found on the server", :status => 404
            return
          else
            @repo = Grit::Repo.new("private/#{@devfile.device.id}/.git")
          end
           
          # 
          repoBlob = @repo.blob(@blob.blob_hash)
          if repoBlob == nil
            render :text => "Blob was not found on the server", :status => 404
            return
          end
  
          sendfile = repoBlob.data
          send_data(sendfile, :type => @devfile.filetype,
                    :filename => @devfile.name,
                    :disposition => 'inline')
          return
          
        rescue => e
          puts "Error getting file from virtual device: " + e
          render :text => "Error getting file from virtual device: " + e, :status => 409
          return
        end
      end
    
    
      # File is found on the normal plavce (not virtual_container)         
      file_name = "public/devfiles/" + @devfile.device_id.to_s + "/" + @blob.blob_hash + "_" + @devfile.name      
      
      if File.exist?(file_name)
        # send the file by using test_meta_worker's send_data method.
        sendfile = File.open(file_name).read
        send_data(sendfile, :type => @devfile.filetype,
                  :filename => @devfile.name,
                  :disposition => 'inline')
        return
        
        
      else
        render :text => "File was not uploaded on the server.", :status => 503
        return
      end
    end
    
  end
  




def checkUserGroupPermission
  if @devfile.device.user.username == @request_user.username and @devfile.device.user.password == @request_user.password
    return true
  end
  allowed = false
  user_groups = @request_user.groups
  @devfile.groups.each do |g|
    if user_groups.find_by_id(g.id) != nil
      return true
    end
  end
  return allowed
end



# Finds device of uri and sets it to the @device variable
  def findDeviceOfURI
    # find device
    if params[:deviceid]
      begin
        @device = Device.find(params[:deviceid])
      rescue
        @device = nil
      end
    elsif params[:devicename] and params[:username]
      @device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
    end
  end
  
  
  # Finds devfile and blob
  def findDevfileAndBlob
    
     # find devfile
    if @device != nil
      puts "PATH: #{@path}"
      puts "FILENAME: #{@filename}"
      puts "DEV_NAME: #{@device.dev_name}"
      @devfile = @device.devfiles.find(:first, :conditions => ['name = ? and path = ?', @filename, @path])
    else
      # If the device was not found
      raise "Device was not found!"
#      render :text => "Device was not found!", :status => 404
#      return
    end
    
    if @devfile == nil
      raise "File not found"
#      render :text => "File not found", :status => 404
#      return
    end
    
    # If no version was given, fetches newest one.
    if params[:version] == nil
      puts "Fetching newest version"
      @blob = @devfile.blobs.find(:first, :conditions => ['id = ?', @devfile.blob_id])
    else
      puts "Fetching version: " + params[:version]
      @blob = @devfile.blobs.find(:first, :conditions => ['version = ?', params[:version]])
    end
    
    # If given version was not found, generates and returns list of versions available.
    if @blob == nil
      s = ""
      @devfile.blobs.each do |b|
        s = s + " " + b.version.to_s + ","
      end
      puts "File didn't have version: " + params[:version] + ". File only have versions:" + s
      raise "File didn't have version: " + params[:version] + ". File only have versions:" + s
#      render :text => "File didn't have version: " + params[:version] + ". File only have versions:" + s, :status => 404
#      return
    end

    
  end
  
  def authenticateFile
    
    begin
    getPathAndFilename
    findDeviceOfURI
    findDevfileAndBlob
    rescue => e
      puts e
      render :text => e, :status => 404
      return
    end

    if @devfile.privatefile
               # client interface
      if params["i_am_client"]

        # the requested resource did not include username
        if !params["username"]
          puts "unknown user, authentication failed (c1)"
          render :text => "Unauthorized - 401", :status => 401
          return
        end

        # authentication tokens missing
        if !params["auth_timestamp"] or !params["auth_hash"]
            puts "unknown user, authentication failed (c2)"
            render :text => "Unauthorized - 401", :status => 401
            return
        end

        # calculate hash and compare with client hash
        @request_user = User.find_by_username(params["username"])
        password = @request_user.password

        # Hash that is calculated from the request
        hash = Digest::SHA1.hexdigest(params["auth_timestamp"] + password + request.path)


        # If hash didn't match to the one given in request params
        if params["auth_hash"] != hash
            puts "unknown user, authentication failed (c3)"
            render :text => "Unauthorized - 401", :status => 401
            return
        end
        
        if @request_user == nil or @request_user.password != password
          puts "Invalid password/username combination!"
          render :text => "Invalid password/username combination!"
          return
        end
            
            
            
        if not checkUserGroupPermission
          render :text => "You have no right to access this file", :status => 403
          return
        else
          return true #getfile
        end
        
            
      else
        
        if session[:username] == @devfile.device.user.username
          return true #getfile
        end
        #authenticate_or_request_with_http_basic do |id, password|
        
        #  puts "username: " + id
        #  puts "password: " + password
        if session[:username] == nil
          render :text => "Not authorized to access this file", :status => 403
          return
        end
        
        @request_user = User.find_by_username(session[:username])
        if @request_user == nil
          render :text => "Problem with authenticating user and looking for access rights!", :status => 403
          return
        end
        
        if not checkUserGroupPermission
          render :text => "You have no right to access this file", :status => 403
          return
        else
          return true #getfile
        end
            
        #end
      end
         

      
    else
      puts "Public file, No authentication needed!"
      return true
    end
  end
  

  # Mark file deleted.
  #
  # Parameters: Filepath (path+filename) and host-device (username+devicename) of the file must
  # be specified in the url. 
  #
  # Method checks that the deletor is the owner of the file and deletes the uploaded file.
  # Returns: Http code 200 - if delete was successful
  #          http code 404 - if the file was not found
  #          http code 403 - if the deletor is not the owner
  #
  # Usage: 
  #   Send DELETE to /user/{username}/device/{devicename}/{filepath}
  def deleteFile
  
    begin
      if @auth_user == nil
        render :text => "Problem with authentication", :status => 403
        return
      end
  
      # Find the file
      getPathAndFilename # Gets @filename and @path
      
      @device = Device.find_by_dev_name_and_user_id(params[:devicename], @auth_user.id)
      
      if @device == nil
        render :text => "Coudn't find the device #{params[:devicename]}", :status => 404
        return
      end
      
      @file = Devfile.find_by_device_id_and_path_and_name(@device.id, @path, @filename)
      if @file == nil
        render :text => "Couldn't find the file #{patams[:filepath]}", :status => 404
        return
      end 
      
      @file.update_attribute(:deleted, true)

    rescue => e
      puts "Error marking content deleted: " + e
      render :text => "Error markind content deleted: ", :status => 404
      return
    end
    
    render :text => "File marked deleted", :status => 200   
    return
  end
  
  
  
  
  # View file rights
  #
  # Parameters: Filepath (path+filename) and host-device (username+devicename) of the file must
  # be specified in the url.
  #
  # Notice that giving permissions for certain file gives the same permissions for all it's versions as well.
  #
  # Method shows the filerights-edit-view.
  #
  def viewFileRights
    
    @message = "Access denied"
    if params[:username] != session[:username]
      render :text => @message, :status => 401
      return
    end
    
    # try to get file from database
    if @error or not fetchFile
      @error = "File not found!"
      return
    end
    
    if @file.privatefile
      @filestate = "private"
    else
      @filestate = "public"
    end
    
    # get all groups of user
    @groups = Group.find(:all, :conditions => ["user_id = ?", @user.id]).sort_by { |a| a.name.downcase }
    
    # checkbox-state of each group
    @group_checked = Array.new
    
    # get all groups associated to the file
    filegroups = @file.groups.find(:all)
    filegroup_ids = []
    filegroups.each do |f|
      filegroup_ids.push(f.id)
    end
    
    # detect groups that have a permission to see file
    if @filestate == "private"
      @groups.each do |group|
        if filegroup_ids.include?(group.id)
          @group_checked << true
        else
          @group_checked << false
        end
      end
    else
      @group_checked = Array.new(@groups.size, true)
    end
  end
  
  
  
  
  
  
  # Edit file access rights
  #
  # Parameters: Filepath and host-device (username+devicename) of the file must
  # be specified in the url. The method can serve client and web requests.
  #
  # Method either makes the file public to all or makes it private and accessible to spesific
  # groups only. Group-data must be given as a parameter in the body of the http request.
  # Syntax (if used from the client): group:[Group_name]=>[1|0]
  #
  # Returns: Http code 200 - if edit was successful (see makePub and makePriv -methods)
  #          http code 404 - if no groups found in parameters
  #          http code 409 - if other error
  #
  # Usage: 
  #   Send POST to /user/{username}/device/{devicename}/filerights/{filepath}  
  def editRights
    if not params[:i_am_client]
      # data is from the form, no need to process it
      if params[:makepublic]
        makePub
      else
        makePriv
      end
      return
    end
    
    
    begin
      public = false
      # checks if parameter public is given, and if its value is true
      # Also generates list of groups given as parameter, if user has those groups
      @groups = Hash.new
      params.each do |p|
        
        if p.first.to_s == 'public' and p.second.to_s == 'true'
          public = true
        end
        group, g_name = p.first.to_s.split(/:/, 2)
        if group == 'group' and g_name != nil
          r = {g_name => p.second.to_s}
          @groups.merge!(r)
        end
      end
    rescue => e
      puts "Error editing filerights: " + e
      render :text => "Error editing filerights: " + e, :status => 409
      return
    end
    
    if public
      puts "Making file public"
      makePub
    elsif not @groups.empty?
      puts "Making file private"
      makePriv
    else
      puts "No groups found in parametres!"
      render :text => "No groups found in parametres! Syntax: group:[Group_name]=>[1|0]", :status => 404
      return
    end
    
    
  end
  
  
  
  
  
  
  # Send upload request for a file to a device
  #
  # Parameters: noRendering - should be true if the method is called internally and no page
  # rendering needed. If called from ajax, parameter id (devfile's id) is required.
  #
  # Can be called internally or from ajax request. Method sends xmpp-message to the host-device
  # of the file and requests it to upload the file. If called from ajax and noRendering = false,
  # method renders part of the page (replaces upload image button with a loader-image).
  #
  def sendUploadRequest(noRendering = false)
    # get @devfile

    # Internal usage
    if noRendering

      if @device == nil
        @device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
      end

      if @device != nil
        # gets @path and @filename
        getPathAndFilename
        @devfile = @device.devfiles.find(:first, :conditions => ["name = ? and path = ?", @filename, @path])
      end
    
    # external usage
    else
      @devfile = Devfile.find_by_id(params[:id].to_i)
      puts "upload request for file " + @devfile.name + "(" + @devfile.id.to_s + ")"
    end
    
    # Devfile has been found:
    # request upload
    if @devfile != nil
   
      # Tries to find the correct version of the file
      if @blob == nil
        @blob = Blob.find_by_id(params[:blob_id])
      end
  
      if @blob != nil

        @commit = Commit.find_by_id(BlobsInCommit.find(:first, :conditions => ["blob_id = ?", @blob.id]).commit_id)
        if @commit != nil

          if @device == nil
            @device = @commit.device

            if @device == nil
              render :text => "fail. no device found", :status => 404
              return
            end
          end
          
          # send request message
          message = "upload " + @devfile.path + @devfile.name + " " + @commit.commit_hash
          XmppHelper::sendXmppMessage(@device.xmppname, message)
          @blob.update_attribute(:upload_requested, true)
          @device.update_attribute(:xmpp_request_sent, DateTime.now)

        end
      end
    else
      render :text => "fail. no file found", :status => 404
      return
    end

    # if the request was from ajax, render part of the page
    if not noRendering
      render :update do |page|
        page[params[:id].to_s + '_upload'].replace_html :partial => 'upload', :locals => {:loading => true, :offline => false}
        poll = 'do_polling_' + params[:id]
        page.assign poll, true
      end   
    end
    
  end
  
  
  # Upload file
  #
  # Parameters: upload - the file that is being uploaded
  #             thumbnail - optional, specifies that the upload is a thumbnail of a file
  #             username+devicename - required in the URL
  #
  # Method handles file uploads from devices. Upload can be either a file (of which metadata can be found
  # from the database) or a thumbnail of a file. Device must initialize the upload by changing it's status with
  # onilne method. Status is changed by giving online method as a parameter status array which has 
  # uploading_file=>true key-value pair. Otherwise upload is not accepted.
  #
  # Returns: Http code 200 - if upload was successful
  #          http code 404 - if file's metadata can't be found
  #          http code 409 - if other error
  #
  # Usage: 
  #   Send PUT to /user/{username}/device/{devicename}/files/{filepath}
  #   (upload must be declared by online with status: uploading_file=>true before this! See online-method.)
  def upload
    
    # If file was not given as a parameter
    if params[:upload] == nil
      render :text => "Error. No file found.", :status => 409
      return
    end
    
    
    puts "filesize: " + params[:upload].size.to_s
 
    # Gets @filename and @path
    getPathAndFilename 
    name = @filename 
    filepath = @path
    puts "filepath: " + filepath    
    puts "filename: " + name
    puts "filetype: " + params[:upload].content_type
    
    # Checks that the file's and it's version's metadata can not be found from database.
    device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
    
    # If uploading thumbnail, some temporary information must be taken away from the name
    if params[:thumbnail]
      name = name.gsub(/.temp./, "")
      name = name.gsub(/.vR_unknown.png/, "")

    # If device is virtual_container, do the rest a bit differently
    elsif device.dev_type == "virtual_container"
      begin
      
        addFileToVirtualContainer(device)
        
      rescue => exp
        putsE(exp)
        raise exp
      end
        
      render :text => "File added to virtual container", :status => 200
      return
      
    end
    
    puts "filename: " + name
    
    
    file = nil
    if device != nil
      device.update_attribute(:last_seen, DateTime.now)
      file = device.devfiles.find(:first, :conditions => ["name = ? and path = ?", name, filepath])
      if file == nil
        puts "FILE NOT FOUND: " + name
        render :text => "Error. File's metadata can not be found.", :status => 404
        return
      end
      
      blob = file.blobs.find(:first, :conditions => ["blob_hash = ?", params[:blob_hash]])
    end
    
    if file == nil or blob == nil
      puts "FILE NOT FOUND: " + name
      render :text => "Error. File's metadata can not be found.", :status => 404
      return
    end
    
    
    if not params[:thumbnail]

      fup = Fileupload.find_by_blob_id(blob.id)
      if fup == nil
        puts "FILE fileupload NOT FOUND: " + name
        render :text => "Error. File's beginUpload sequence not initialized.", :status => 409
        return
      end

    end

    
    # Creates new file:
    if params[:thumbnail]
      # If file was thumbnail, creates new thumbnail.
      createFile(params[:upload].read, file, blob, params[:blob_hash],true)
    else
      # If file wasn't thumbnail, creates actual file.
      createFile(params[:upload].read, file, blob, params[:blob_hash])
      fup.update_attribute(:end_time, DateTime.now)
    end
    render :text => "File has been uploaded successfully", :status => 200
    
  end
  
  
  # Adds file to virtual container
  def addFileToVirtualContainer(device)

    dev_path = "private/#{device.id}/"
   
    # create dir if it does not exist
    if not (File.exists?(dev_path) && File.directory?(dev_path))
      FileUtils.mkdir_p(dev_path)      
    end    
    
    # If devfile with same name on same device exist, make new blob for the devfile
    prev_devfile = Devfile.find_by_name_and_path_and_device_id( @filename, '/', device.id)
    
    path = File.join(dev_path, @filename)
    # write the file
    File.open(path, "wb") { |f|   
      puts f.to_s
      f.write(params[:upload].read)
    }
    puts "completepath: " + dev_path
    puts "File " + @filename + " created."
    
    # Add the new file to git and create blob
    addToGitAndCreateBlob(device, dev_path, @filename, prev_devfile)
    
    # Delete the file, since it is added to git
    File.delete(path)    
  end

  def addToGitAndCreateBlob(device, dev_path, filename, prev_devfile)
    
    # If git repository doesn't yet exist for this device, create it
    if not File.exists?("#{dev_path}.git")
      # Create new repo
      @repo = Grit::Repo.init_bare("#{dev_path}.git", {:bare => false})
    else
      # Repo already existed
      @repo = Grit::Repo.new("#{dev_path}.git")
    end
    
    # Add file to repo and make a commit
    @repo.add("#{dev_path}#{filename}")    
    @repo.commit_all("new commit")

    commit_hash = @repo.commits.first.id
    commited_blob = @repo.commits.first.tree.contents.first.contents.first.contents.last
    
    
    # Check type of file
    contenttype = "unknown"  
    if not MIME::Types.type_for(filename).to_s.empty?
        contenttype = MIME::Types.type_for(filename).to_s
    end
    
    # Create thumbnail
    thumbnail_name = createThumbnail(commited_blob, contenttype, device)
    
    
    # Add blob to database
    blob = Blob.create(:size => commited_blob.size,
                       :filedate => DateTime.now,
                       :uploaded => 1,
                       :version => 0,
                       :blob_hash => commited_blob.id,
                       :thumbnail_name => thumbnail_name)
           
    if blob == nil
      raise Exception.new("Problem creating blob")
    end       
           
    # This is used for making sure old blob won't end up in blobs_in_commit table
    old_blob = nil
           
    # If first version of file, create devfile
    if prev_devfile == nil     
      # Add devfile to database
      devfile = Devfile.create(:device_id => device.id,
                               :name => filename,
                               :path => '/',
                               :filetype => contenttype,
                               :privatefile => 1,
                               :blob_id => blob.id)
    # If adding new version of file, update link to new blob
    else
      old_blob_id = prev_devfile.blob_id
      
      # Update version number of blob
      old_blob = Blob.find_by_id(old_blob_id)
      old_blob.follower_id = blob.id
      old_blob.save
      blob.version = old_blob.version.to_i+1
      blob.predecessor_id = old_blob_id
      blob.save
      
      # Update old devfile
      devfile = prev_devfile
      devfile.blob_id = blob.id
      devfile.updated_at = blob.filedate
      devfile.save
    end
              
    if devfile == nil
      raise Exception.new("Problem creating devfile")
    end
                  
    # Tell blob which devfile it belongs to 
    blob.devfile_id = devfile.id
    blob.save
    
    previous_commit = device.commit_id
                   
    # Create commit
    commit = Commit.create(:device_id => device.id,
                           :commit_hash => commit_hash,
                           :previous_commit_id => previous_commit)
    
    if commit == nil
      raise Exception.new("Problem creating commit")
    end

    # create new link between blob and commit
    blobInCommit = BlobsInCommit.create(:blob_id => blob.id,
                                        :commit_id => commit.id)

    if blobInCommit == nil
      raise Exception.new("Problem creating blob in commit")
    end
      
    # Link old blobs into new commit
    if previous_commit != nil    
      old_blobs = BlobsInCommit.find_all_by_commit_id(previous_commit)
      if old_blobs != nil
        old_blobs.each do |x|
          if x.blob_id != old_blob_id
            BlobsInCommit.find_or_create_by_blob_id_and_commit_id(x.blob_id, commit.id)
          end
        end
      end
    end
      
    # update device info
    device.update_attribute(:last_seen, DateTime.now)
    device.update_attribute(:commit_id, commit.id)

  end
  
  def createThumbnail(blob, contenttype, device )

    thumb_path = "public/thumbnails/#{device.id}/"
    
    thumb_name = blob.id.to_s+".png"

    if contenttype == "image/jpeg" or contenttype == "image/png" or contenttype == "image/gif"
        createIcon(blob.data, thumb_name, thumb_path)
        return thumb_name
        
    elsif contenttype == "video/x-msvideo"
      format = blob.name.split(".").last
      if format == 'avi'
        vR_default_thumbnail_file = "vR_avi.png"
      elsif format == 'mov'
        vR_default_thumbnail_file = "vR_mov.png"
      end
        
    elsif contenttype == "application/mswordapplication/x-mswordapplication/x-wordapplication/wordtext/plain"
      vR_default_thumbnail_file = "vR_doc.png"
    elsif contenttype == "application/x-ruby"
      vR_default_thumbnail_file = "vR_ruby.png"
    elsif contenttype == "text/plain"
      vR_default_thumbnail_file = "vR_txt.png"
    else
      vR_default_thumbnail_file = "vR_unknown.png"
    end
    
    # create dir if it does not exist
    if not (File.exists?(thumb_path) && File.directory?(thumb_path))
      FileUtils.mkdir_p(thumb_path)
    end
      
    # Copy default thumbnail to file
    from = "public/thumbnails/vR_default_thumbnails/" + vR_default_thumbnail_file
    to = thumb_path+thumb_name
    
    # ftools (ruby 1.8.7)
    #File.copy(from, to )
    
    # fileutils (ruby 1.9.2)
    FileUtils.cp(from, to )
    
     
    return thumb_name
  end
  
  

  
#  Change metadata or add new metadata
#
#  Parameters: metadata_type
#              metadata_value
#
#  Returns: Http code 201 - If new metadata has been added
#           Http code 200 - If metadata has been changed
#           Http code 404 - Failed to add/update metadata
# 
#  examples with curl: 'curl -X POST http://localhost:8080/user/heikki/device/test22/metadata/pallo.jpg -d "metadata_type=people&metadata_value=0"'
#                      'curl -X POST http://localhost:8080/user/heikki/device/test22/metadata/pallo.jpg?version=1 -d "metadata_type=tyyppi&metadata_value=arvo"'
#                      'curl -X POST http://localhost:8080/user/heikki/device/test22/metadata/2.jpg -d "metadata_type=description&metadata_value=kuvaus"'
#
  def changeMetadata
    begin
      
      
      # Gets parameters
      typename = params[:metadata_type].to_s.strip.downcase
      value = params[:metadata_value].to_s.strip

      if typename == ""
        render :text => "Type of metadata not given.", :status => 404
        return
      end
      
      if value == ""
        render :text => "Value of metadata not given.", :status => 404
        return
      end
      
      # Search for the user
      @user = User.find_by_username(params[:username].to_s.strip)
      if not @user
        # If the user was not found
        return
        render :text => "User not found.", :status => 404
      end
  
      # Search for the device
      findDeviceOfURI
      if @device != nil
        getPathAndFilename
        @devfile = @device.devfiles.find(:first, :conditions => ['name = ? and path = ?', @filename, @path])
        if @devfile == nil
          render :text => "File was not found.", :status => 404
          return
        end
      else
        # If the device was not found
        render :text => "Device was not found.", :status => 404
        return
      end
      
      # If updating description to devfile
      if typename == "description"
        @devfile.update_attribute(:description, value)
        render :text => "Metadata description updated", :status => 201
        return
      # If updating filetype to devfile
      elsif typename == "filetype"
        #TODO: Check valid mime type
                   
        @devfile.update_attribute(:filetype, value)
        render :text => "Metadata filetype updated", :status => 201
        return
        
      # If updating metadata in blob
      elsif typename == "uploaded" or typename == "latitude" or typename == "longitude" or typename == "filedate" or typename == "file_status"
        # Looks for right version of the file
        if params[:version] != nil
          puts "Fetching version: " + params[:version]
          @blob = @devfile.blobs.find(:first, :conditions => ['version = ?', params[:version]])
          if not @blob
            render :text => "Version of the file was not found.", :status => 404
            return
          end
          if typename == "filedate"
            # Create new DateTime object from given value            
            newtime = DateTime.strptime(value, '%F %T')
            @blob.update_attribute(:filedate, newtime)
            render :text => "Metadata filedate updated", :status => 201
            return
          elsif typename == "uploaded" or typename == "file_status"        
            if value == "0" #or intti == 1    can only be changed to non-cached
              intti = value.to_i
              puts "foo"        
              @blob.update_attribute(:uploaded, intti)
              render :text => "Metadata uploaded updated", :status => 201
              return
            else
              render :text => "Invalid metadata value", :status => 404
              return
            end
          
          elsif typename == "latitude"
            latitude = value.to_f
            @blob.update_attribute(:latitude, latitude)                                
            render :text => "Metadata latitude updated to #{latitude}", :status => 201
            return                   
          elsif typename == "longitude"
            longitude = value.to_f
            @blob.update_attribute(:longitude, longitude)
            render :text => "Metadata longitude updated to #{longitude}", :status => 201
            return
          end
        # If version of the file was not given
        else
          render :text => "Version of the file needed.", :status => 404
          return
        end
        
      # Can't change metadata value from: name, path, creater_at, updated_at, privatefile, 
      #                                     size, upload_requested, thumbnail_name, version, blob_hash  
      elsif typename == "name" or typename == "path" or typename == "created_at" or typename == "privatefile" or
            typename == "size" or typename == "upload_requested" or typename == "thumbnail_name" or
            typename == "version" or typename == "blob_hash"
        render :text => "Can't change this metadata from devfile or blob.", :status => 404
        return
        
      else    
        # Checks that metadata type is already added
        type = MetadataType.find_by_name(typename)
    
        if not type
          # If there is not such metadata type already added
          render :text => "Metadata type not found. Please add metadata type first.", :status => 404
          return
        end
        
        # Checks that value is either string/float/date/datetime, according to value_type from metadata_types
        if type.value_type == "string"
          # String doesn't need to be checked?
          
        elsif type.value_type == "float"
          # Check that value has float
          if value !~ /^\s*[+-]?((\d+_?)*\d+(\.(\d+_?)*\d+)?|\.(\d+_?)*\d+)(\s*|([eE][+-]?(\d+_?)*\d+)\s*)$/
            render :text => "Invalid float type", :status => 404
            return
          end
          
        elsif type.value_type == "date"
          # Check that value is valid date
          
          value = QueryController::transform_date(value) 

          begin
            Date.new(value[0..3].to_i, value[5..6].to_i, value[8..9].to_i)
          rescue 
            render :text => "invalid date", :status => 404
            return
          end
        
        elsif type.value_type == "datetime"
          if not QueryController::check_datetime(value)
            render :text => "invalid datetime", :status => 404
            return
          end

        else
          # Couldn't find value_type. You should never find yourself here
          render :text => "Error adding metadata, contact support hotline", :status => 404
          return
        end

        
        # 
        if @devfile
          
          metadata = Metadata.find(:first, :conditions => ['metadata_type_id = ? and devfile_id = ?', type.id, @devfile.id])
          if metadata and typename != "tag"
            metadata.update_attribute(:value, value)
            
            
            if typename == "context_hash"
              
              
              context = Context.find_by_context_hash(value)
              if context 
                Thread.new{
                  puts "kylla lahtee"
                  XmppHelper::notificationToContextNode(@devfile, context, "Context content updated!")                 
                }
              end
            end
            
            
            render :text => "Metadata value changed", :status => 200
            return
          end      
          if params[:version] != nil
            puts "Fetching version: " + params[:version]
            @blob = @devfile.blobs.find(:first, :conditions => ['version = ?', params[:version]])
            if not @blob
              render :text => "Version of the file was not found.", :status => 404
              return
            end
            Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(value, @blob.id, @devfile.id, type.id)
          else      
            Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(value, nil, @devfile.id, type.id)
          end
          render :text => "Metadata added", :status => 201
          return
        end
      end
      
    rescue ArgumentError
        render :text => "Invalid arguments", :status => 409
    rescue => e
        puts "Error in updating metadata".background(:red)
        puts e
    end
  end


#  Delete metadata
#
#  Parameters: metadata_type
#              (metadata_value - If deleting multi metadata (tag), need to give value of metadata to be deleted)
#              
#  Returns: Http code 200 - Metadata deleted
#           Http code 404 - Failed to delete metadata
# 
#  Example with curl: 'curl -X DELETE http://localhost:8080/user/heikki/device/test22/metadata/2.jpg -d "metadata_type=new_type"'
#
  def deleteMetadata
    begin
      # Gets parameters
      typename = params[:metadata_type].to_s.strip.downcase
      puts "t: " + typename
      
      if typename == ""
        render :text => "Type of metadata not given", :status => 404
        return
      end

      
      # Metadatatypes that can't be deleted
      #if  typename == "name" or typename == "path" or typename == "description" or typename == "filetype" or
      #    typename == "created_at" or typename == "updated_at" or typename == "privatefile" or
      #    typename == "size" or typename == "filedate" or typename == "uploaded" or typename == "upload_requested" or
      #    typename == "thumbnail_name" or typename == "version" or typename == "blob_hash"
      #  render :text => "Can't delete this metadata", :status => 404
      #  return
      #end
      
      # Search for the user
      @user = User.find_by_username(params[:username].to_s.strip)
      if not @user
        # If the user was not found
        render :text => "User not found", :status => 404
        return
      end
  
      # Search for the device
      findDeviceOfURI
      if @device != nil
        getPathAndFilename
        @devfile = @device.devfiles.find(:first, :conditions => ['name = ? and path = ?', @filename, @path])
        if @devfile == nil
          render :text => "File was not found.", :status => 404
          return
        end
      else
        # If the device was not found
        render :text => "Device was not found.", :status => 404
        return
      end      

      # Search for the metadatatype
      type = MetadataType.find_by_name(typename)      
      if type == nil
        render :text => "Metadatatype not found", :status => 404
        return        
      end
          
      # If trying to delete metadata of multi metadatatype
      if @@multi_metadata_types_for_context.include?(typename)
        if not params[:metadata_value]
          render :text => "Value of multi metadata not given", :status => 409
          return
        end

        md_value = params[:metadata_value].to_s.strip.downcase
        
        # Try to find certain metadata of multi values type
        metadata = Metadata.find_by_metadata_type_id_and_devfile_id_and_value(type.id, @devfile.id, md_value)
      else
        # Search for the "normal" metadata  
        metadata = Metadata.find(:first, :conditions => ['metadata_type_id = ? and devfile_id = ?', type.id, @devfile.id])
      end
      
      if metadata 
        metadata.destroy
        render :text => "Metadata deleted", :status => 200
        return
      else
        render :text => "Can't find metadata", :status => 404
        return
      end    
             
    rescue => e
      puts "Error in deleting metadata".background(:red)
      puts e
    end
  end


  
  #--------------------------------------------------------------------------------------------
  # ---- PRIVATE METHODS ----------------------------------------------------------------------
  
  private
  

  
  
  
  
  
  
  # Make file public
  #
  # Helper method for editRights-method (same prerequisites). Removes all access rights binded to the file
  # and makes it public to all. Renders a view for either the client or web-UI.
  #
  # Parameters: i_am_client must be given when using from client.
  #
  # Returns: Http code 200 - if file has been successfully made public
  #          http code 404 - if file not found
  #
  def makePub #:doc:
    # try to get file from database
    if not fetchFile
      if params[:i_am_client]
        render :text => "File not found", :status => 404
        return
      else
        @error = "File not found!"
        render "viewFileRights"
        return
      end
    end
    
    # if file is private
    if @file.privatefile
      #change state
      @file.update_attribute(:privatefile, false)
      
      # delete all file-related permissions
      begin
        DevfileAuthUser.delete_all(["devfile_id = ?", @file.id])
      rescue
        # do nothing (no rows found)
      end
      begin
        DevfileAuthGroup.delete_all(["devfile_id = ?", @file.id])
      rescue
        # do nothing (no rows found)
      end
    end
    
    if params[:i_am_client]
      render :text => "#{@file.name} is now public.", :status => 200
      return
    else
      flash[:notice] = "#{@file.name} is now public!"
      redirect_to :action => "viewFileRights"
    end
  end
  
  
  
  
  # Make file private
  #
  # Parameters: i_am_client must be given when using from client. groups - which groups of the user 
  # have access rights to the file + everything required by editRights
  #
  # Helper method for editRights-method (same prerequisites). Makes file private and binds
  # access rights to the file. After that the file can be accessed by specific groups only.
  # Renders a view for either the client or web-UI.
  #
  # Returns: Http code 200 - if file has been successfully made private
  #          http code 404 - if file not found
  #  
  def makePriv #:doc:
    if params[:i_am_client] and params[:groups] == nil
      # Groups were searched in editRights-method
      param_groups = @groups
    else
      param_groups = params[:groups]
    end
    
    # try to get file from database
    if not fetchFile
      if params[:i_am_client] 
        render :text => "File not found", :status => 404
        return
      else
        @error = "File not found!"
        render "viewFileRights"
        return
      end
    end
    
    begin 
      # all groups owned by user
      mygroups = Group.find(:all, :conditions => ["user_id = ?", @user.id])
      
      # all groups associated with the file
      filegroup_ids = Array.new
      @file.groups.find(:all).each do |t|
        filegroup_ids.push(t.id)
      end
      
      # check which groups should have access to file
      delete_auth_groups = ""
      mygroups.each do |mygroup|
        if param_groups[mygroup.name] == "1" and not filegroup_ids.include?(mygroup.id)
          # if group-checkbox is checked, group gets permission to access file
          @file.devfile_auth_groups.create(:group_id => mygroup.id)
        elsif param_groups[mygroup.name] == "0" and filegroup_ids.include?(mygroup.id)
          # if group-checkbox is not checked, unauthorize fileaccess to this file
          if delete_auth_groups == "" then delete_auth_groups += "group_id IN (#{mygroup.id}"
          else delete_auth_groups += ", #{mygroup.id}" end
        end
      end
      if delete_auth_groups != ""
        delete_auth_groups += ") AND devfile_id = ?"
        DevfileAuthGroup.delete_all([delete_auth_groups, @file.id])
      end
      
      # make file private
      @file.update_attribute(:privatefile, true)
      
    rescue => e
      puts "Error in editing filerights: " + e
      if params[:i_am_client] 
        render :text => "Error in editing filerights: " + e, :status => 409
        return
      else
        @error = "Error in editing filerights: " + e
        render "Error in editing filerights: " + e
        return
      end
    end
    
    if params[:i_am_client]
      render :text => "#{@file.name} visibility modified.", :status => 200
      return
    else
      flash[:notice] = "#{@file.name} visibility modified."
      redirect_to :action => "viewFileRights"
    end
  end
  
  
  def only_filename(file_name)
    # get only the filename, not the whole path (from IE)
    file_name.gsub(/^.*(\\|\/)/, '')
  end
  
  def sanitize_filename(file_name)
    # replace all none alphanumeric, underscore, spaces or perioids with underscore
    file_name.gsub(/[^\w\.\_\s]/,'_')
  end
  

  
  
  # Creates a new file or thumbnail on the disk. 
  # The path for files is public/devfiles/{deviceid}/{blob_hash}_{filename} and for thumbnails: 
  # public/thumbnails/{deviceid}/{blob_hash}_{filename}.
  #
  # Parameters: readfrom - stream to read the file from
  #             file - file metadata (devfile-object)
  #             blob - the version of the file
  #             blob_hash - the unique id for the file
  #             thumbnail - true if the file to be created is a thumbnail of a file
  #
  # Method reads stream and creates a file to the filesystem. Used when a file is uploaded.
  #
  def createFile(readfrom, file, blob, blob_hash, thumbnail = false) #:doc:
    
    devfiles_base = ""
    if thumbnail
      # If file was thumbnail, saves the file in different location.
      devfiles_base = "public/thumbnails/"
    else
      devfiles_base = "public/devfiles/"
    end
    
    complete_path = devfiles_base + file.device_id.to_s + "/"
    puts "completepath: " + complete_path
    
    
    # create dir if it does not exist
    if not (File.exists?(complete_path) && File.directory?(complete_path))
      FileUtils.mkdir_p(complete_path)
    end
    
    filename = blob_hash + '_' + file.name
    
    if thumbnail
      filename = blob_hash
      contenttype = MIME::Types.type_for(filename).to_s
      if contenttype != "image/jpeg" and contenttype != "image/png" and contenttype != "image/gif"
        filename += ".png"
      end
      
#      # Adds thumbnail name for file in db
#      blob.update_attribute(:thumbnail_name, filename)
      
     # Add thumbnail_name for blob
     devid = blob.devfile.device_id
     blobs = Blob.find_by_sql("Select blobs.* from blobs, devfiles where blobs.blob_hash = '#{blob_hash}' and devfiles.device_id = #{devid} and blobs.devfile_id = devfiles.id")
     blobs.each do |b|
       if not b.thumbnail_name
         b.update_attribute(:thumbnail_name, filename)
       end
     end
      
    end
    
    puts "Filename: " + filename
    
    # create the file path
    path = File.join(complete_path, filename)

    # write the file
    File.open(path, "wb") { |f|   
      puts f.to_s
      f.write(readfrom) }
    puts "File " + file.name + " created."
    if not thumbnail
      blob.update_attribute(:uploaded, true)
      blob.update_attribute(:upload_requested, nil)
    end
  end

  

  
  # Fetch file metadata
  #
  # Parameters: username+devicename must be found in the request url. 
  # @filename and @path must be set before calling this method (see method getPathAndFilename)
  # 
  # Used by fileright-methods to set @file.
  #
  # Result: @user, @device, @file, @blob, @filename and @path is set after calling this method.
  #
  def fetchFile #:doc:
    
    begin
      @user = User.find_by_username(params[:username])
      @device = @user.devices.find_by_dev_name(params[:devicename])
      
      getPathAndFilename
      @file = @device.devfiles.find(:first, :conditions => ["name = ? and path = ?", @filename, @path])
      @blob = Blob.find_by_id(@file.blob_id)
    rescue => e
      puts e
      return false
    end
    
    # if not found
    if @file == nil
      return false
    end
    return true
  end
  
  
end
