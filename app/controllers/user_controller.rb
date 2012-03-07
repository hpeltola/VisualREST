class UserController < ApplicationController
  
  # Protection from cross site request forgery
  protect_from_forgery :except => [ :addGroup, :deleteGroup, :register, :deleteUser, :deleteDevices,
                                    :deleteDevice, :deleteDeviceFiles, :deleteAllUserFiles, 
                                    :createContext, :modifyContext, :modifyUser, :addNode, :deleteNode,
                                    :contextSettings, :emailSettings, :virtualContainerSettings, 
                                    :importContentFromFlickr, :getThumbnail, :getUser, :facebookWriteOnWall,
                                    :twitterPublish, :facebookConnected, :twitterConnected,
                                    :dropboxConnected, :flickrConnected, :flickrPublishPhoto,
                                    :facebookPublishPhoto, :uploadFromBrowser, :dropboxUpload]
  
  # These methods need authentication:
  before_filter :authenticate, :only => [:settings, :addGroup, :deleteGroup, :deleteUser, 
                                         :deleteDevices, :deleteDevice, :deleteDeviceFiles,
                                         :deleteAllUserFiles, :editUsersGroups, :saveUsersGroups,

                                         :deviceSettings, :modifyUser, :manageEmails,
                                         :addObserver, :emailSettings, :contextSettings, 
                                         :virtualContainerSettings, :importContentFromFlickr, 
                                         :importContentFromFB, :facebookPublishPhoto, :facebookWriteOnWall,
                                         :twitterPublish, :facebookConnected, :twitterConnected,
                                         :dropboxConnected, :flickrConnected, :facebookImportAlbum,
                                         :flickrDeleteToken, :flickrImportPhotos, :flickrPublishPhoto,
                                         :uploadFromBrowser, :dropboxUpload ]

  before_filter :authenticateAPI, :only => [:doc]
  
  
  
  ###################################################################################################
  
  
  def index
    @title = "VisualREST"
  end
  
  
    def signature(base_string, consumer_secret,token_secret='') 
      secret="#{consumer_secret}&#{token_secret}" 
      Base64.encode64(HMAC::SHA1.digest(secret,base_string)).chomp.gsub(/\n/,'') 
    end
 
  
  def testi
    
=begin    # Remove broken links in devfile_auth_groups
    begin
      counter = 0
      devgroups = DevfileAuthGroup.find(:all)
      devgroups.each do |x|
        devfile = Devfile.find_by_id(x.devfile_id)
        if not devfile
          counter += 1
          DevfileAuthGroups.delete_all(:devfile_id => x.devfile_id)
        end
      end
   rescue => e
      puts "Problem with the test function. E: #{e}"
      render :text => "Problem with the test function. E: #{e}"
      return
    end
    
    render :text => "Found #{counter} broken links in devfile_auth_groups and removed them!", :status => 200
=end    return
    
  end


  def checkMetadataType(metadata_type_name)
    
    type = MetadataType.find_by_name(metadata_type_name)
    if type
      return type.value_type
    
    else
    #type = Devfiles.find_by_sql
    
    
      return nil
    end
    
    
    
  end


  def uploadInWebUI
    
    begin
      
      if params[:upload]
        
        # Find the device
        device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
        
        if device == nil
          render :text => "Could not find the device"
          return
        end
        
        user = User.find_by_username(params[:username])
        
        if user == nil
          render :text => "Could not find the user"
          return
        end
        
        # Get the filename from the upload data
        @filename = "/" + params[:upload]['datafile'].original_filename
        
        # Create the manager      
        @virtualContainerManager = VirtualContainerManager.new(user, device.dev_name)
        
        # Add file with the manager
        @virtualContainerManager.addFile(@filename, params[:upload]['datafile'].read)
        
        # Make the commit
        @virtualContainerManager.commit
      
      else
         render :text => "No file selected, try again..."
         return
      end
      
      render :text => "File has been uploaded successfully <br /> " +
                      "<a href='/user/#{params[:username]}/device/#{params[:devicename]}/'>Return</a><br />" +
                      "<a href='/user/#{params[:username]}/device/#{params[:devicename]}/files'>See files</a>"
      
    rescue => e
      puts "Problem uploading with Web-UI. E: #{e}"
      render :text => "Problem uploading with Web-UI. E: #{e}"
    end
  end

  
  def uploadFromBrowser
    
          
    begin
      
      if params["access-control-allow-origin"] && params["access-control-allow-origin"] == "true"
        headers['Access-Control-Allow-Origin'] = '*'
        #headers['Access-Control-Request-Method'] = '*'  
      end
        
      if params[:upload]
        
        # Find the device
        device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
        
        if device == nil
          render :text => "Could not find the device"
          return
        end
        
        user = User.find_by_username(params[:username])
        
        if user == nil
          render :text => "Could not find the user"
          return
        end
        
        # Get the filename from the upload data
        @filename = "/" + params[:upload]['datafile'].original_filename
        
        # Create the manager      
        @virtualContainerManager = VirtualContainerManager.new(user, device.dev_name)
        
        # Add file with the manager
        @virtualContainerManager.addFile(@filename, params[:upload]['datafile'].read)
        
        # Make the commit
        @virtualContainerManager.commit
      
      else
         render :text => "No file selected, try again..."
         return
      end
      
      render :text => "File has been uploaded successfully <br /> " +
                      "<a href='/user/#{params[:username]}/device/#{params[:devicename]}/'>Return</a><br />" +
                      "<a href='/user/#{params[:username]}/device/#{params[:devicename]}/files'>See files</a>"
      
    rescue => e
      puts "Problem uploading with Web-UI. E: #{e}"
      render :text => "Problem uploading with Web-UI. E: #{e}"
    end
    
  end


  def getUser
    
    query_processing_time_begin = Time.now
    # In web-ui query processing time is only shown if asked. In atom-feed, it is always shown.
    if params["query_processing_time"] && params["query_processing_time"].downcase == "true"
      @query_processing = true
    end
    if params[:qoption] && params[:qoption]["query_processing_time"] == "true"
      @query_processing = true
    end

    @json_callback = nil
    if params[:qoption] && params[:qoption]["json_callback"]
      @json_callback = params[:qoption]["json_callback"]
    end

    if params[:qoption] && params[:qoption]["format"]
      params[:format] = params[:qoption]["format"]
    end
    
    # Signed in with web-ui?
    if session[:username]
      username = session[:username]
    elsif params[:i_am_client]
      username = authenticateClient
    else
      flash[:notice] = "You must login first"
      redirect_to :action => "login", :controller => "user"
      return
    end
    
    if username != nil
      @signed_in_user = User.find_by_username(username)
    end
        
    if @signed_in_user == nil
      render :text => "Oops, problem with authentication", :status => 409
      return
    end
    
    @user = User.find_by_username(params[:username])
    
    if @user == nil
      render :text => "Oops, couldn't find the user info'", :status => 404
      return
    end

    
    groups = @user.groups
    own_groups = Group.find_all_by_user_id(@user.id)
    @groups = Array.new
    @own_groups = Array.new
    # This is for json/yaml
    @user_friends = Array.new
    # Same as above, but for web-interface
    @friends = Hash.new
    # Find additional info for every group
    
    begin
      groups.each do |x|
        if x.user_id == @user.id
          next
        end
        # Get list of user's 'friends', aka users in same groups
        x.users.each do |xx|
          @friends[xx.id] = xx.username
        end
        tmp = Hash.new
        tmp["name"] = x.name
        tmp["owner_name"] = User.find_by_id(x.user_id).username
        tmp["members"] = Usersingroup.count_by_sql "SELECT COUNT(*) FROM usersingroups u WHERE u.group_id = #{x.id}"
        @groups.push(tmp)
      end
      
      own_groups.each do |x|
        # Get list of user's 'friends', aka users in same groups
        x.users.each do |xx|
          if xx.id != @user.id
            @friends[xx.id] = xx.username
            @user_friends.push(xx.username)
          end
        end
        tmp = Hash.new
        tmp["name"] = x.name
        tmp["members"] = Usersingroup.count_by_sql "SELECT COUNT(*) FROM usersingroups u WHERE u.group_id = #{x.id}"
        @own_groups.push(tmp)
      end
    rescue => e
      puts e
      render :text => "Problem finding groups user is in", :status => 409
      return
    end
    
    
    if params[:format] == "yaml" or params[:format] == "json"
      @yaml_results = {}

      begin

        userObject = UserObject.new(@user, params[:format], @groups, @own_groups, @user_friends)
        @yaml_results.merge!({userObject.get_uri => userObject.to_yaml})
        
      rescue Exception => e
        putsE(e)
      end
      puts @yaml_results.to_s
    end

        
    if query_processing_time_begin != nil
      query_processing_time_end = Time.now
      @query_processing_time = query_processing_time_end - query_processing_time_begin
      puts "Time used for processing query: #{@query_processing_time}"
    end
        
        
    # Rendering
    @host = @@http_host
    
    respond_to do |format|
      if params[:format] == nil
        format.html {render :getUser}
      else
        format.html {render :getUser}
        format.atom { render :getUser, :layout=>false }
        format.yaml { render :text => YAML.dump(@yaml_results), :layout=>false }
        if @json_callback == nil
          format.json { render :text => JSON.dump(@yaml_results), :layout=>false }
        else
          format.json { render :text => @json_callback + '(' + JSON.dump(@yaml_results) + ')', :layout=>false }
        end
      end
    end
  end


  # Used by backup service
  # Returns: 200 - if user is authenticated with parameters (i_am_client, auth_username, auth_timestamp, auth_hash) 
  def authenticateUser
    username = authenticateClient
    
    if username == nil
      render :text => "Error, failed to authenticate user!", :status => 401
      return      
    end
  
    render :text => "User authentication OK!", :status => 200
    return
  end

  # Get user's thumbnail
  # Thumbnails are public, so this function doesn't require authentication
  def getThumbnail
    
    # Find the user whose thumbnail is requested
    user = User.find_by_username(params[:username])
    
    if user == nil
      render :text => "Could not find the user", :status => 404
      return
    end
    
    # Find the thumbnail
    if File.exists?("public/thumbnails/user_thumbnails/#{user.username}.png")
      file_data = File.open("public/thumbnails/user_thumbnails/#{user.username}.png", "rb").read
      
      
    else
      # If thumbnail not found, use default
      file_data = File.open("public/thumbnails/vR_user_128.png", "rb").read
    end
    
    
    # Return the thumbnail to whom requested it
    
    if params["access-control-allow-origin"] && params["access-control-allow-origin"] == "true"
      headers['Access-Control-Allow-Origin'] = '*'
      #headers['Access-Control-Request-Method'] = '*'  
    end
    send_data(file_data, :type => 'image/jpeg',
              :filename => user.username,
              :disposition => 'inline')
    return    
  end


 # Manage users email accounts
 # Used for fetching mail and saving attachments to to server
 def emailSettings
   if not session[:username]
     render :text => "Error, failed to authenticate user!", :status => 401
     return
   end

  @user = User.find_by_username(session[:username])

  if @user == nil
    render :text => "Error, failed to find user!", :status => 401
    return
  end

  # Email addresses saved for the user
  @userEmails = UserEmail.find_all_by_user_id(@user.id)
  
  @virtualUserDevices = Device.find_all_by_user_id_and_dev_type(@user.id, "virtual_container")
  
  render :update do |page|
    page["email_settings"].replace_html :partial => 'email_settings'
  end

 end
 
 
  # Manage users contexts.
  # See contexts that user: - has access to
  #                         - has saved to his contexts
  #
  # Change contextnames for this user
  def contextSettings
    
   if not session[:username]
     render :text => "Error, failed to authenticate user!", :status => 401
     return
   end
    
    # User needs to be signed in
    @user = User.find_by_username(session[:username])
    if @user == nil
      render :text => "Error, failed to find user!", :status => 401
      return
    end
    
    # Get all contexts
    all_contexts = Context.find(:all)
   
    # Get two groups of contexts that user has access to: 
    #     1. contexts that user has access to, but has not yet added to own contexts
    #     2. contexts that user has added to his contexts
    
    # Group 1
    hasAccess = Array.new
    
    # Group 2
    hasAdded = ""
    
    # Go through all contexts
    all_contexts.each do |x|
      
      # Is user authorized to this context?
      if not authorizedToContext(x.context_hash)
        next
      end
      
      # User is authorized for this context, see if it is already added to users context_name list
      if ContextName.find_by_context_id_and_user_id(x.id, @user.id) == nil
        hasAccess.push(x.id)
        next
      else
        if hasAdded == ""
          hasAdded = x.id.to_s
        else
          hasAdded = hasAdded + " ," + x.id.to_s
        end
      end
      
    end
    
    # Finally get the contexts for the view
    if not hasAccess.empty?
      @hasAccess = Context.find_all_by_id(hasAccess)
    else
      @hasAcecss = nil
    end
    
    if not hasAdded.empty?
      
      @hasAdded = Context.find_by_sql( "SELECT contexts.name as c_name, contexts.context_hash as c_context_hash, 
                                               context_names.username as username, context_names.name as ctx_name,
                                               users.username as owner_name
                                        FROM contexts, context_names, users
                                        WHERE users.id = contexts.user_id AND
                                              contexts.id = context_names.context_id AND
                                              context_names.user_id = #{@user.id} AND
                                              contexts.id IN (#{hasAdded})")
    else
      @hasAdded = nil
    end
    
    render :update do |page|
      page["context_settings"].replace_html :partial => 'context_settings'
    end
  end
  
  
  # Manage virtual containers
  # You can:
  # - Add them
  # - Change name
  def virtualContainerSettings
    
   if not session[:username]
     render :text => "Error, failed to authenticate user!", :status => 401
     return
   end
    
    # User needs to be signed in
    @user = User.find_by_username(session[:username])
    if @user == nil
      render :text => "Error, failed to find user!", :status => 401
      return
    end
    
    # Create new virtual device
    if params[:create_virtual_device] == "true" && params[:dev_name] && params[:dev_type] == "virtual_container"
      try_new_name = Device.find_by_user_id_and_dev_name(@user.id, params[:dev_name].strip.downcase)
        if try_new_name == nil
          if params[:dev_name].strip.downcase =~/^[-a-z0-9_]+$/
            # Create the new virtual device
            @user.devices.create(:dev_name => params[:dev_name].strip.downcase,
                                :dev_type => params[:dev_type],
                                :last_seen => DateTime.now,
                                :direct_access => false,
                                :xmppname => "",
                                :xmpppasswd => "")
          end
        end
      
    end
    
    # Changing container name?
    if params[:old_name] && params[:new_name]
      # Make sure there isn't a device with same name on same user
      try_new_name = Device.find_by_user_id_and_dev_name(@user.id, params[:new_name].strip.downcase)
      if try_new_name == nil
        if  params[:new_name].strip.downcase =~/^[-a-z0-9_]+$/
          device = Device.find_by_user_id_and_dev_type_and_dev_name(@user.id, "virtual_container", params[:old_name].strip)
          if device != nil
            device.dev_name = params[:new_name].strip.downcase
            device.save
          end
        end
      end
      
    end
    
    # Get list of users virtual containers
    @devices = Device.find_all_by_user_id_and_dev_type(@user.id, "virtual_container")
    
    
    
    render :update do |page|
      page["virtual_container_settings"].replace_html :partial => 'virtual_container_settings'
    end
    
  end




  # Register new user to the system.
  #
  # Parameters: username must be given in uri /user/{username}/. 
  # password and real_name must be given in http request parameters.
  #
  # Method can be used from client and from web site.
  # If used from client:
  #   Renders text: Conflict and returns http code 409 if something goes wrong in registration. 
  #   If user is successfully registered renders text and returns http code 201.
  # If used from web site:
  #   Redirects to index, and shows message that user is created successfully.
  #   If errors in registration, shows messages on registration page.
  # Usage::
  #   Send PUT to /user/{username}/ with parameters: password and real_name.
  def register
    @title = "Register"
    if (request.put? and params[:user]) or (request.put? and params[:username])
      
      # web-ui
      if params[:user]
        @user = User.new(params[:user])
        
        email_add = @user.username + @@domain
        @user.email = email_add
        
        if @user.save
          
          session[:user_id] = @user.id
          session[:username] = @user.username
          flash[:notice] = "User #{@user.real_name} created!"
          redirect_to :action => "index", :controller => "user"
        end
        # No else needed, if something goes wrong uses models' messages in registration form.
      
      # client
      else
        email_add = params[:username] + @@domain
        
        @user = User.create(:real_name => params[:real_name], 
                            :username => params[:username], 
                            :password => params[:password],
                            :email => email_add)

        if request.ssl?
          @request_url = "https://#{request.host}"
        else
          @request_url = "http://#{request.host}"
        end

        if @user.save
          @host = @@http_host
          respond_to do |format|
            format.atom {render :userCreated, :layout=>false }
          end        
        else
          render :text => "Conflict - 409 \n", :status => 409
        end
        
      end
      
    end
  end
    
    
  # Modify user information. Mainly mail addresses.
  def modifyUser

    user = User.find_by_username(params[:username])
    
    if user == nil
      render :text => "Couldn't find user", :status => 404
      return
    end
    
    begin 
      # If adding new email address
      if params[:add_email] 
        ### Make some checkings. If not passed, will return error -> user can edit the fields and try again.
        if params[:add_email].strip == ""
          render :text => "Mail address needed", :status => 409
          return
        end
        
        if params[:mail_port] && params[:mail_port].strip != "" && (not params[:mail_port].strip =~/^[0-9]+$/ )
          render :text => "Problem with port number", :status => 409
          return
        end
        
        
        # Make sure user doesn't already have that mail address added
        test = UserEmail.find_by_user_id_and_email(user.id, params[:add_email].strip)
        if test != nil
          render :text => "Mail address already exists", :status => 409
          return
        end
        
        ### end checkings
        
        
        added = UserEmail.find_or_create_by_user_id_and_email(:user_id => user.id, 
                                                              :email => params[:add_email].strip,
                                                              :mail_checking => "false")
                                                              
        if added != nil
          puts "Added new email: #{params[:add_email]} to user: #{user.username}"
          
          if params[:mail_username] && params[:mail_username].strip != "" &&
             params[:mail_password] && params[:mail_password].strip != "" &&
             params[:mail_server] && params[:mail_server].strip != "" &&
             params[:mail_port] && params[:mail_port].strip != "" && params[:mail_port].strip =~/^[0-9]+$/ &&
             params[:mail_tls_encryption] && params[:mail_tls_encryption] != "" &&
             params[:to_device] && params[:to_device] != ""
            
            # Save the mail account info
            added.update_attribute(:mail_username, params[:mail_username].strip )
            added.update_attribute(:mail_password, params[:mail_password].strip )
            added.update_attribute(:mail_server, params[:mail_server].strip )
            added.update_attribute(:mail_port, params[:mail_port].strip )
            added.update_attribute(:mail_checking, "false" )

            if params[:mail_tls_encryption] == "true" || params[:mail_tls_encryption] == "false"
              added.update_attribute(:mail_tls_encryption, params[:mail_tls_encryption])
            end
            
            device_id = Device.find_by_user_id_and_dev_type_and_dev_name(user.id, "virtual_container", params[:to_device])
            if device_id != nil
              added.update_attribute(:device_id, device_id.id)
            end
            
            if params[:mail_checking] && params[:mail_checking].strip.downcase == "true"
              # Add persistent checking to a mail account
              # Will fetch attachments from new mails and mark the mail as unread
              added.update_attribute(:mail_checking, "true" )
              
              
            end
          end
        end                                                            
      
      end
    rescue Exception => e
      puts "SERVER PROBLEM WHEN ADDING NEW MAIL ADDRESS" 
    end

    
    # If removing existing email address
    if params[:remove_email] && params[:remove_email].strip != ""
      remove = UserEmail.find_by_user_id_and_email(user.id, params[:remove_email])
      
      puts "Remove email address"
      if remove != nil
        UserEmail.delete(remove.id)
      end
    end
    
    # If changing email persistent checking for email account
    if params[:change_email_persistent] && params[:change_email_persistent].strip != ""
      change = UserEmail.find_by_user_id_and_email(user.id, params[:change_email_persistent])
      
      puts "Change persistent checking for address: #{params[:change_email_persistent]}"
      if change != nil
        if change.mail_checking == true
          change.update_attribute(:mail_checking, false)
        else
          change.update_attribute(:mail_checking, true)
        end
      end
    end
    
    # If adding thumbnail to user
    if params[:thumbnail_data]
        thumbnail_name = "#{user.username}.png"
        thumbnail_path = "public/thumbnails/user_thumbnails/"
        puts "Thumbnail created!" if createIcon(params[:thumbnail_data].read, thumbnail_name, thumbnail_path)
    end
    
    render :text => "Success modifying your account", :status => 200
    return
  end    
    
    
  # Adds users certain device to observe modifications of certain file
  #
  # params: file_uri - the uri of the file that is going to be observed
  #
  # renders 200 - if ok
  # renders 404 - if the observed file not found
  # renders 401 - if the requester doesn't have right to add observed files.
  #
  # Example: curl -X PUT http://localhost:8443/user/ollipolli/my_n8/observe -d "file_uri=http://localhost:8443/user/ollipolli/device/my_n8/files/foobar.txt?version=0" -d "i_am_client=true"
  #
  def addObserver
    
    begin

      #if not identifyDevice(false)
      #  render :text => "Unauthorized - 401 \n", :status => 401
      #  return
      #end
       
      if not @auth_user
        render :text => "Unauthorized - 401 \n", :status => 401
        return
      end
        
      puts "Observed.."
      uri = params[:file_uri].to_s
      puts "..uri: " + uri
      
      nodepath = params[:node_path].to_s
      puts nodepath
      if not nodepath or nodepath == ""
        render :text => "No node_path given!", :status => 409
        return
      end
      
      o_username, o_devicename, o_filepath, o_filename, o_version = parseFileInfoFromURI(uri)
      
      o_user = User.find_by_username(o_username)
      o_device = o_user ? o_user.devices.find_by_dev_name(o_devicename) : nil
      o_devfile = o_device ? o_device.devfiles.find_by_name_and_path(o_filename, o_filepath) : nil
      if not o_devfile or not o_user or not o_devfile
        puts "Error: observed file not found!"
        render :text => "Error: observed file not found! \n", :status => 404
        return
      elsif not o_user.xmpp_host or not o_user.xmpp_jid or not o_user.xmpp_pw
        render :text => "Error: No xmpp_host, xmpp_jid or xmpp_pw! \n", :status => 404
        return
      end
      
      #@node = Node.find(:first, :conditions => [ "nick_name = ?", params[:node_nick]])
      #FileObserver.find_or_create_by_user_id_and_devfile_id_and_node_path(:user_id => o_user.id, :devfile_id => o_devfile.id, :node_path => params[:node_path], :node_service => @@node_client_info[:node_service])
      
      
      fo = FileObserver.find(:first, :conditions => ['user_id = ? and devfile_id = ? and node_path = ?', o_user.id, o_devfile.id, nodepath])
      
      if not fo
        puts "uusi"
        fo = FileObserver.create(:user_id => o_user.id, :devfile_id => o_devfile.id, :node_path => nodepath, :node_service => "pubsub.#{o_user.xmpp_host}")
        puts fo.id
      else
        puts "vanha"
      end
      
      
      if params[:ajax] and params[:obsDId]
        puts "Renderointi: #{params[:obsDId]}"
        render :update do |page|
          page[params[:obsDId]].replace_html :partial => 'obsReqSent'#, :locals => {:status => stat, :image => params[:image]} 
        end
        return
      end

      render :text => "Observing now: #{uri} \n", :status => 200
      return
    
    rescue Exception => e
      putsE(e)
      render :text => "Error", :status => 500
      return        
    end
  end
  
    
 
   
    
    
=begin
  def deleteRepo(username)
    path = "public/repos/users/#{username}.git"
    # Deletes repository
    if File.directory?(path)
      puts "Deleting repository..."
      FileUtils.rm_rf(path)
      puts "Repository deleted."
    end
  end
=end
  
  
  # <b>DEPRECATED:</b> currently users can't be deleted.
  #
  # Removes user, users groups and all his/hers devices and their content from the system.
  #
  # parameters: username must be given in uri /user/{username}/. 
  #
  # Renders text and returns http code 409 if something goes wrong. 
  # If user is successfully removed renders text: User deleted and returns http code 200.
  # Method requires authentication
  # Usage: 
  #   Send DELETE to /user/{username}/ with parameters: password and real_name.
  def deleteUser
    puts "Deleting user: #{@user.username}..."
    
    # Deletes user devices and all files from them
    if deleteDevices(false)
      
      @groups = Group.find(:all, :conditions => ["user_id = ?", @user.id])
      puts "Deleting groups: " + @groups.length.to_s
      # Deletes all groups from user
      @groups.each do | g |
        @group = g
        puts "Deleting group: #{@group.name}"
        deleteGroup(true)
      end
      
      puts "Groups deleted.."
      
      begin
        @user.delete
      rescue => e
        puts "Error deleting user from db: " + e
      end
      
      render :text => "User deleted - 200", :status => 200
    else
      render :text => "Couldn't delete user's devices. User not deleted!", :status => 409
    end
  end
  
  # <b>DEPRECATED:</b> currently devices can't be deleted.
  #
  # Removes devices and their content from user.
  #
  # parameters: username must be given in uri /user/{username}/devices. 
  #
  # Renders text and returns http code 409 if something goes wrong. 
  # If devices are successfully removed renders text and returns http code 200.
  #
  # Method requires authentication.
  #
  # Method can be used through REST API or from another method in this controller.
  # Usage (through REST): 
  #   Send DELETE to /user/{username}/devices
  # Usage (from another method):
  #   deleteDevices(true)
  def deleteDevices(direct = false)
    
    no_errors = true
    puts "Deleting user: #{params[:username]} devices.."
    @user.devices.each do | d |
      @device = d
      no_errors = false if not deleteDevice(true)
    end
    
    if not direct
      if no_errors
        # if no errors
        render :text => "OK - 200", :status => 200
      else
        render :text => "Conflict - 409", :status => 409
      end
    else
      return no_errors
    end
  end
  
  
  
  # Method for viewing device's settings.
  # Method initializes google map, that show device's last location
  def deviceSettings  
    initDeviceMap
    deviceCurrentLocation
    
    # Find all user's groups
    @groups = Array.new
    groups = Group.find_all_by_user_id(@auth_user.id)
    
    groups.each do |x|
      group = x
      group["device_in_group"] = false
      
      if DeviceAuthGroup.find_by_device_id_and_group_id(@device.id, group.id)
        group["device_in_group"] = true
      end
      
      @groups.push(group)
    end
    
  end


  def updateDeviceLocationsMap
    initDeviceMap

    if params[:showPath] == 'true'
      deviceCurrentLocation
      deviceLocationsPath
    else
      deviceCurrentLocation
    end
    
  end

  def initDeviceMap
      @user = User.find_by_username(params[:username])
      @device = Device.find(:first, :conditions => ["dev_name = ? and user_id = ?", params[:devicename], @user.id])
      
      @online_status = "offline"
      
      if @device.last_seen > 2.minutes.ago
        @online_status = "online"
      end
      
      @map = GMap.new("map_div_id")
      @map.control_init(:large_map => true, :map_type => true)
      
      if @online_status == "online"
        @onlinepicuri = "/thumbnails/vR_online_2_32.png"
      else
        @onlinepicuri = "/thumbnails/vR_offline_32.png"
      end
      @map.icon_global_init( GIcon.new(
            :image => @onlinepicuri,
            :shadow => "http://www.google.com/mapfiles/shadow50.png",
            :icon_size => GSize.new(32,32),
            :shadow_size => GSize.new(37,32),
            :icon_anchor => GPoint.new(9,32),
            :info_window_anchor => GPoint.new(9,2),
            :info_shadow_anchor => GPoint.new(18,25)), "online_icon")
      
      @online_icon = Variable.new("online_icon")
      
      @current_location = DeviceLocation.find_by_id(@device.latest_location_id)
  end

  def deviceCurrentLocation
    
    if @current_location != nil
      info_message = '<b>' + @device.dev_name + '</b>' + " was seen here on  " + @current_location.updated_at.to_s + '<br/>' + 
      "Device is " + @online_status + '<img src="' + @onlinepicuri + '" /> <br/>' + 
      '<a href="/user/' + @user.username + '/device/' + @device.dev_name + '/files">Files of ' + @device.dev_name + '</a>'
      
      @map.center_zoom_init([@current_location.latitude,@current_location.longitude], 12)
      @current_pos_marker = GMarker.new([@current_location.latitude, @current_location.longitude],
                                        :title => @device.dev_name, 
                                        :info_window => info_message,
                                        :icon => @online_icon)
      
      @map.overlay_init(@current_pos_marker)
    end
  end


  def deviceLocationsPath
    
    locations = DeviceLocation.find(:all, :conditions => ["device_id = ?", @device.id])
    
    @places_path = []

    locations.each do |l|

      if not l.latitude or not l.longitude
        next
      end
      @places_path << GLatLng.new([ l.latitude, l.longitude ])
      
      if l.id != @current_location.id
        m = GMarker.new([l.latitude, l.longitude], 
                         :title => @device.dev_name, 
                         :info_window => @device.dev_name + " was seen here on  " + l.updated_at.to_s)
        @map.overlay_init(m)        
      end
    end
    
   
    
  end
  

  
  
  # <b>DEPRECATED:</b> currently files can't be deleted.
  #
  # Removes device and its content from user.
  #
  # parameters: username must be given in uri /user/{username}/device/{devicename}.
  # If used through REST:
  #   Renders text and http code 404 if device is not found.
  #   Renders text and returns http code 409 if something goes wrong. 
  #   If devices are successfully removed renders text and returns http code 200.
  #
  # If used from another method:
  #   Returns false if device not found.
  #   Returns false if errors.
  #   Retruns true if deletion succeeded.
  #
  # Method requires authentication.
  #
  # Method can be used through REST API or from another method in this controller.
  #
  # Usage (through REST): 
  #   Send DELETE to /user/{username}/device/{devicename}
  # Usage (from another method):
  #   deleteDevice(true) and set @device
  def deleteDevice
    begin
      @device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
      if @device == nil
        render :text => "Device #{params[:devicename]} not found", :status => 404
        return
      else
        
        puts "Deleting device: #{@device.dev_name}..."
        dh = DeleteHelper.new(@device.id)
        dh.removeDevice
      end
      
    rescue => e
      puts "Error in deleting device from db:" + e 
      render :text => "Conflict 2 - 409", :status => 409
      return
    end

    puts "Whole device deleted!"  
    render :text => "Device delete - 200", :status => 200
    return    
  end
  
  
  
  # <b>DEPRECATED:</b> currently files can't be deleted.
  #
  # Deletes files from device but not the actual device
  #
  # parameters: username and devicename must be given in uri /user/{username}/device/{devicename}/files. 
  #
  # Method can be used through REST API and from another method.
  # If used through REST:
  #   Renders text and http code 404 if device is not found.
  #   Renders text and returns http code 409 if something goes wrong. 
  #   If devices are successfully removed renders text and returns http code 200.
  #
  # If used from another method:
  #   Returns false if device not found.
  #   Returns false if errors.
  #   Retruns true if deletion succeeded.
  #
  # Method requires authentication.
  #
  # Usage (through REST): 
  #   Send DELETE to /user/{username}/device/{devicename}/files
  # Usage (from another method):
  #   deleteDeviceFiles(true) and set @device before calling
  def deleteDeviceFiles
    
    puts "foo"
    
    @device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
    if not @device
      render :text => "Device #{params[:devicename].to_s} not found", :status => 404
      return
    end
    
    puts "bar"
    
    begin
      puts "Deleting files of device: #{@device.dev_name}..."
      dh = DeleteHelper.new(@device.id)
      dh.removeContent
    rescue
      puts "Errors in deleting device files: " + e
      render :text => "Error in deleting files of device: #{@device.dev_name}", :status => 409
      return
    end
    
    render :text => "Files of device: #{@device.dev_name} deleted", :status => 200
    return
  end


  # <b>DEPRECATED:</b> currently files can't be deleted.
  #
  # Deletes all files from user.
  #
  # parameters: username must be given in uri /user/{username}/files. 
  #
  # Renders text and returns http code 409 if something goes wrong. 
  # If devices are successfully removed renders text and returns http code 200.
  #
  # Method requires authentication.
  #
  # Usage: 
  #   Send DELETE to /user/{username}/files
  def deleteAllUserFiles
    if @user == nil
      render :text => "User not found", :status => 404
    end
    no_errors = true
    begin
      @user.devices.each do |d|
        @device = d
        no_errors = false if not deleteDeviceFiles(true)
      end
    rescue => e
      puts "Errors in deleting files from user: #{@user.username} (#{d.name}): " + e
      render :text => "Errors in deleting files from user: #{@user.username}", :status => 409
    end
    
    if no_errors
      puts "Files deleted successfully from user: #{@user.username}"
      render :text => "Files deleted successfully from user: #{@user.username}", :status => 200
    else
      puts "Errors in deleting files from user: #{@user.username}"
      render :text => "Errors in deleting files from user: #{@user.username}", :status => 409      
    end
  end


  # Check users login information when they login through web interface.
  #
  # parameters: user -object is given as a parametre from login form.
  #
  # If informations matches, adds userinformation into session and redirects to index page.
  # Otherwise shows error messages on the login page.
  def login 
    @title = "Log in VisualRest" 
    if request.post? and params[:user] 
      
      # creates new user variable
      @user = User.new(params[:user])
      
      # sets local variable user, if username and password can be found from the db
      user = User.find_by_username_and_password(@user.username, 
                                                @user.password) 
      if user 
        # if user was found, puts id of the user in session
        session[:user_id] = user.id 
        session[:username] = @user.username
        
        flash[:notice] = "User #{user.real_name} logged in!" 
        
        redirect_to :action => "index"
      else
        # Don't show the password in the view
        @user.password = nil 
        flash[:notice] = "Invalid screen name/password combination"
        redirect_to :action => "index", :controller => "user"
        return
      end 
    end 
  end
  
  
  # Used to logout users from web site.
  # Removes user infromation from session and redirects to index page.
  def logout
    session[:user_id] = nil
    session[:username] = nil
    flash[:notice] = "Logged out"
    redirect_to :action => "index", :controller => "site"
  end
  

  
  # This method is used to show users their settings. 
  # Currently only lists users groups and some links releated to those.
  # Users needs to be logged in.
  def settings
    @title = "Settings of " + session[:username]
    user = User.find_by_username(session[:username])
    @groups = Group.find(:all, :conditions => ["user_id = ?", user.id])
    
  end
    
  
  def modifyObserversForFile
    
    begin
      @title = "Add observed file"
      
      @file_uri = params[:file_uri]
      puts "fileuri: #{@file_uri}"      
      if @file_uri
        @observed_file = getDevfileFromURI(@file_uri)
        @user = User.find_by_username(session[:username])
        if @user
          
          # Make sure the user has xmpp settings set.
          if @user.xmpp_jid == nil || @user.xmpp_pw == nil || @user.xmpp_host == nil || @user.xmpp_jid == nil
            render :text => "Problem with user's xmpp settings. Go to 'settings -> Node settings'.", :status => 400
            return
          end
          
          client_info = {:id => @user.xmpp_jid+'@visualrest.cs.tut.fi', :psword => @user.xmpp_pw,
                         :host => @user.xmpp_host, :port => 5222, :plain_id => @user.xmpp_jid,
                         :node_service => "pubsub.#{@user.xmpp_host}"}
          @node_names = XmppHelper::getMyNodes(client_info, true)
        else
          render :text => "User not logged in!", :status => 300
          return    
        end
        
        @observers_checked = []
        i = 0
        @node_names.each do |nick, nodepath|
          if FileObserver.find(:first, :conditions => ["devfile_id = ? and user_id = ? and node_path = ?", @observed_file.id, @user.id, nodepath])
            @observers_checked[i] = true
          else
            @observers_checked[i] = false
          end
          i += 1
        end
      else
        raise Exception.new("No file_uri -parameter was found!")
      end
      
    rescue Exception => e
      putsE(e)
    end
  
  end

  def saveObserversForFile
      
    begin
      # Asks user's groups, and the user object
      @devices = Device.find(:all, :conditions => ["user_id = ?", session[:user_id]])
      @user = User.find(:first, :conditions => ["id = ?",session[:user_id]])
      @file_uri = params[:file_uri]
      @observed_file = getDevfileFromURI(@file_uri)
      @observers = @observed_file.file_observers
      
      puts "oid: #{@observed_file.id.to_s}"

      if @user
        client_info = {:id => @user.xmpp_jid+'@visualrest.cs.tut.fi', :psword => @user.xmpp_pw,
                       :host => @user.xmpp_host, :port => 5222, :plain_id => @user.xmpp_jid,
                       :node_service => "pubsub.#{@user.xmpp_host}"}
        @node_names = XmppHelper::getMyNodes(client_info, true)
      else
        render :text => "User no logged in!", :status => 300
        return    
      end

      

      @node_names.each do |nick, nodepath|
        fo = nil
        if @observers != nil and not @observers.empty?
          fo = @observers.find(:first, :conditions => ["devfile_id = ? and user_id = ? and node_path = ?", @observed_file.id, @user.id, nodepath])
        end
        if params[:observers][nodepath] == "1" and fo == nil
          FileObserver.create(:user_id => @user.id, :devfile_id => @observed_file.id, :node_path => nodepath, :node_service => "pubsub.#{@user.xmpp_host}")
        elsif params[:observers][nodepath] == "0" and fo != nil
          @observers.destroy(fo)
        else
          #puts ""
        end
      end
      
      flash[:notice] = "Observers modified."
      redirect_to :action => "modifyObserversForFile", :file_uri => @file_uri
      
    rescue Exception => e
      putsE(e)
    end
    
  end
  



  # Adds new group for certain user.
  #
  # parameters: If used from web site takes group object from form. 
  # If used from client needs username and groupname from uri: /user/{username}/group/{groupname}/.
  #
  # Method can be used from REST and from web-site.
  # If used from web site:
  #   Redircts to settings shows message, if group was saved successfully.
  #   If group with same name for user already exists, shows error message.
  #
  # If used through REST:
  #   Renders text and http code 201, if group was saved successfully.
  #   Renders text and http code 409, if group with same name for user already exists.
  #
  # Method requires authentication.
  #
  # Usage (through REST): 
  #   Send PUT to /user/{username}/group/{groupname}
  def addGroup
    user = User.find_by_username(params[:username])
    if params[:groupname]
      
      @group = Group.find_or_create_by_name_and_user_id(:name => params[:groupname], :user_id => user.id)
      
      if @group
        render :text => "Group #{@group.name} created - 201", :status => 201
        return
      end 
    end
    
    # If adding group failed
    render :text => "Error in creating new group - 409", :status => 409
    return
  end
  
  
  # Deletes group from certain user.
  #
  # parameters: Needs username and groupname from uri: /user/{username}/group/{groupname}
  #
  # If used from another method:
  #   Returns true, if group was deleted successfully.
  #   Returns false, if group couldn't be deleted.
  #
  # If used through REST:
  #   Renders text and http code 200, if group was deleted successfully.
  #   Renders text and http code 409, if group couldn't be deleted.
  #
  # Method requires authentication 
  #
  # Method can be used through REST API or from another method in this controller.
  # Usage (through REST): 
  #   Send DELETE to /user/{username}/group/{groupname}
  # Usage (from another method):
  #   deleteGroup(true) and set @user and @group before calling
  def deleteGroup(fromAnotherMethod = false)

    # If method is not used from another method, user and group needs to be searched
    if not fromAnotherMethod
      @user = User.find_by_username(params[:username])
      @group = Group.find(:first, :conditions => ["name = ? and user_id = ?", params[:groupname], @user.id])
      
      if @user == nil or @group == nil
        puts "Group deletion failed!"
        render :text => "User or Group not found - 404", :status => 404
        return
      end
    end
    
    
    puts "Deleting group: #{@group.name}..."  
    
    # Deletes users from the group 
    puts "Deleting users from the group..."
    @group.users.each do |u|
      authgroup = u.groups.find(:first, :conditions => ["group_id = ?", @group.id])
      if authgroup
        u.groups.delete(authgroup)
      end
    end
    
    # Deletes devfile_auth_groups
    DevfileAuthGroup.delete_all(:group_id => @group.id)
    
    # Deletes device_auth_groups
    DeviceAuthGroup.delete_all(:group_id => @group.id)
    
    puts "Deleting group #{@group.name} from db.."
    # Deletes the actual group
    @group.delete

    render :text => "OK - 200", :status => 200
    return
    
  end
  
  
  
  
  # Multiple users can be added to or removed from user's group at a time. This method 
  # is used to resolve users groups, which are then listed on web site. 
  # The form data is saved by method: saveUsersGroups
  #
  # Method requires authentication
  def editUsersGroups
    if session[:username] and params[:user] and params[:user] !~ /[^\w\_\-]/
      # get signed in user and groups owned by the user
      @user = User.find_by_username(session[:username])
      @groups = Group.find_by_sql("SELECT groups.* FROM groups WHERE groups.user_id = #{@user.id}")

      # string for finding users
      usersstring = searchtermForSql(params[:user], "users.username") + " OR " + searchtermForSql(params[:user], "users.real_name")
      
      # fill users_and_groups with each found users user.id as the key and an array of
      # group.id's as a value (the groups the user BELONGS to)
      users_and_groups = Hash.new
      Usersingroup.find_by_sql("SELECT usersingroups.* FROM groups, usersingroups, users WHERE (" + usersstring +
                          ") AND groups.user_id = #{@user.id} AND usersingroups.user_id = users.id AND " +
                          "groups.id = usersingroups.group_id ORDER BY usersingroups.user_id").each do |ug|
        if not users_and_groups.has_key?(ug.user_id)
          users_and_groups.merge!({ug.user_id => []})
        end
        users_and_groups[ug.user_id].push(ug.group_id)
      end
     
      # will include all users found by the searchterm and information wether each
      # of them belongs or not to each group owned by the signed in user
      @users = Hash.new
      
      # create the base of the group-hash that will be included in the @users.hash as a value for each user
      group_hash = Hash.new
      @groups.each do |group|
        
        group_hash.merge!({group.id => false})
      end
      
      # construct @users, key is the user and value is his group_hash (true/false for belonging to each group)
      User.find_by_sql("SELECT users.* FROM users WHERE " + usersstring).each do |u|
        gh = group_hash.dup
        if users_and_groups.has_key?(u.id)
          users_and_groups[u.id].each do |g|
            gh[g] = true
          end
        end
        @users.merge!({u => gh})
      end
      
    end
  end
  

  # Method is used to add and remove multiple users at a time to group owners groups. 
  # Method can be used from client and from web site (method: editUsersGroups)
  #
  # parameters: groups hash, which comes from form or as a parameter from client
  #
  # After operation redirects to editUsersGroups, and shows message.
  # 
  # Usage: user/:username/saveUsersGroups/:user_id
  #
  def saveUsersGroups
    @user = User.find_by_username(session[:username])
    # get user ids
    user_ids_string = ""
    first = true
    params[:groups].each do |user, users_groups|
      if first then user_ids_string += "user_id = #{user}"
      else user_ids_string += " OR user_id = #{user}" end
      first = false
    end
    
    # fill users_and_groups with each found users user.id as the key and an array of
    # group.id's as a value (the groups the user BELONGS to)
    users_and_groups = Hash.new
    Usersingroup.find(:all, :conditions => user_ids_string).each do |ug|
      if not users_and_groups.has_key?(ug.user_id)
        users_and_groups.merge!({ug.user_id => []})
      end
      users_and_groups[ug.user_id].push(ug.group_id)
    end
    
    
    now = DateTime.now.strftime('%F %T')
    
    modified_groups_for_pubsub_node = []
    
    
    # go through given group settings for each given user and update their group settings
    params[:groups].each do |user_id, user_group_settings|
      user_group_settings.each do |group_id, checked|
        if checked == "1" and (users_and_groups[user_id.to_i] == nil or not users_and_groups[user_id.to_i].include?(group_id.to_i))
          # user isn't previously a member of the group, so he needs to be added to the group
          Usersingroup.find_or_create_by_user_id_and_group_id(:user_id => user_id, :group_id => group_id)
          
          modified_groups_for_pubsub_node << group_id
          
        elsif checked == "0" and (users_and_groups[user_id.to_i] != nil and users_and_groups[user_id.to_i].include?(group_id.to_i))
          # user is previously a member of the group, so he needs to be removed from the group
          Usersingroup.delete_all(['user_id = ? and group_id = ?', user_id, group_id])

          modified_groups_for_pubsub_node << group_id
          
        end    
      end
    end
    
    
    # Sends notifications
    if not modified_groups_for_pubsub_node.empty?
      modified_groups_for_pubsub_node.uniq!
      modified_groups_for_pubsub_node.each do |group_id|
        checkIfContexGroup(group_id)
      end
    end
    
    flash[:notice] = "Groups modified."
    redirect_to :action => "editUsersGroups"
  end  
  
  

  
  
  
  
  
  
  # For editing single user groups
  
  # Method is used to add and remove users to multiple groups at a time. This method 
  # is used to resolve users groups, which are then listed on web site. 
  # The form data is saved by method: saveUserGroups
  #
  # Method requires authentication  
  def editUserGroups
    
    # Finds group owner and his/hers groups
    @user = User.find_by_username(session[:username])
    @groups = Group.find(:all, :conditions => ["user_id = ?", @user.id])
    
    # Finds user who is going to be add/removed to group owner's groups.
    @edit_user = User.find_by_id(params[:user_id])
    
    # Resolves in which groups user is already in.
    @group_checked = []
    @groups.each do |group|
      
      if @edit_user.groups.find(:first, :conditions => ["group_id = ?", group.id])
        @group_checked << true
      else
        @group_checked << false
      end
    end
  end
  
  
  
  
  
  
  
  # Method is used to add and remove certain user to group owners groups. Method is used 
  # and from web site (method: editUserGroups)
  #
  # parameters: groups hash, which comes from form.
  #
  # After operation redirects to editUserGroups, and shows message.
  def saveUserGroups
    
    # Asks user's groups, and the user object
    @groups = Group.find(:all, :conditions => ["user_id = ?", session[:user_id]])
    @edit_user = User.find_by_id(params[:user_id])
    
    # check which groups should have access to file
    @groups.each do |group|
      
      authgroup = @edit_user.groups.find(:first, :conditions => ["group_id = ?", group.id])
      if params[:groups][group.name] == "1" and authgroup == nil
        Usersingroup.find_or_create_by_user_id_and_group_id(:user_id => @edit_user.id, :group_id => group.id)
        
      elsif params[:groups][group.name] == "0" and authgroup != nil
        # if group-checkbox is not checked
        @edit_user.groups.delete(authgroup)
      end
    end
    
    
    flash[:notice] = "#{@edit_user.real_name} groups modified."
    redirect_to :action => "editUserGroups"
    
  end
  
  
  def checkIfContexGroup(group_id)
    begin
      
      Thread.new{
      
      sql = "SELECT contexts.* 
             FROM contexts, context_group_permissions, groups 
             WHERE groups.id = '" + group_id.to_s + "' AND 
                   groups.id = context_group_permissions.group_id AND 
                   context_group_permissions.context_id = contexts.id LIMIT 1;"
      
      context = Context.find_by_sql(sql).first
      
      if context
     
          begin
            puts "Sends notification to node!"
            XmppHelper::publishToContextGeneralNode(context, "Context Members Modified!", "context-modified")
            puts "Notification sent!"
          rescue Exception => ee
            putsE(ee)
          end    
      end
      }
    rescue Exception => ec
      putsE(ec)
    end
    
    
  end
  
  
  # Method for this document
  def doc
    
    if not session[:username]
      puts "unknown user, authentication failed e2"
      flash[:notice] = "You must login first"
      redirect_to :action => "login", :controller => "user"
      return
    else
      render :file => "#{RAILS_ROOT}" + request.request_uri.to_s   
    end
  end
   

  def authenticateAPI
    authenticate_or_request_with_http_basic do |id, password| 
      if id == "vrAPI" and password == "vrAPI"
        return true
      end 
    end
    return false
  end

  
  
  
  
  def groupsettings
    if session[:username]
      @user = User.find_by_username(session[:username])
      @groups = Group.find(:all, :conditions => ["user_id = ?", @user.id])
      render :update do |page|
        page["group_settings"].replace_html :partial => 'usergroup' 
      end
    end
  end
  
  
  def nodeSettings
    
    puts "tanas"
    
    @xmpp_host = @@xmpp_host
    if session[:username]
      @user = User.find_by_username(session[:username])
      
      @node_service = "pubsub.#{@@xmpp_host}"
      @xmpp_host = @@xmpp_host
      
      @node_path_base = "home/#{@@xmpp_host}/#{@user.username}/"
      
      @userNodes = []
      if @user.xmpp_jid and @user.xmpp_jid != "" and @user.xmpp_pw and @user.xmpp_pw != ""
      
        client_info = {:id => @user.xmpp_jid+'@'+@@xmpp_host, :psword => @user.xmpp_pw,
                       :host => @@xmpp_host, :port => @@xmpp_port, 
                       :node_service => "pubsub.#{@@xmpp_host}"}
        
        @userNodes = XmppHelper::getMyNodes(client_info)
      end
      
      render :update do |page|
        page["node_settings"].replace_html :partial => 'node_settings' 
      end
      return 
    end
  end
  
  

  
  def addXMPPAccount
    puts "foo"
    @xmpp_id = params["xmppid"].to_s.strip + '@' + @@xmpp_host
    @xmpp_pw = params["xmpppw"].to_s.strip
    
    puts @xmpp_id + " : " + @xmpp_pw
    
    i = 0
    begin
      cl = Jabber::Client.new(Jabber::JID.new(@xmpp_id))
      cl.connect(@@xmpp_host, @@xmpp_port)
      cl.register(@xmpp_pw)
      cl.close
    rescue Exception => ex
      putsE(ex)
      if i < 5
        i += 1
        sleep(1)
        retry
      else
        cl.close
        render :text => "Error in creating an account! Already exists?", :status => 409
        return
      end
    end
    
    @user = User.find_by_username(params[:username])
    @user.update_attribute(:xmpp_jid, params["xmppid"])
    @user.update_attribute(:xmpp_pw, @xmpp_pw)
    @user.update_attribute(:xmpp_host, @@xmpp_host)
    
    render :text => "Account added", :status => 200
    return  
  end
  
  def editXMPPAccount
    
    begin
      @user = User.find_by_username(params[:username])
      @user.update_attribute(:xmpp_jid, params["xmppid"])
      @user.update_attribute(:xmpp_pw, params["xmpppw"])
      @user.update_attribute(:xmpp_host, @@xmpp_host)
    
    rescue Exception => ex
      putsE(ex)
      render :text => "Details was not be saved!", :status => 409
      return
    end
    
    render :text => "Account added", :status => 200
    return 
  end
  
  
  
  
  def addNode
    begin
      @xmpp_host = @@xmpp_host
      @user = User.find_by_username(params[:username])
    
      client_info = {:id => @user.xmpp_jid+'@'+@@xmpp_host, :psword => @user.xmpp_pw,
                     :host => @@xmpp_host, :port => @@xmpp_port, 
                     :node_service => "pubsub.#{@@xmpp_host}"}

      if NodeHelper.new(params[:nodepath], client_info, true).createNode    
        puts "Node created successfully!"
        render :text => "OK - 200", :status => 200
        return
      else
        puts "Creating node failed!"
        render :text => "Deleting node failed!", :status => 200
        return
      end

    rescue Exception => e
      puts "Error in creating node!"
      render :text => "Error in creating node!", :status => 200
      return
    end    
  end
  
  
  
  def deleteNode
    begin
      @xmpp_host = @@xmpp_host
      @user = User.find_by_username(params[:username])
    
      client_info = {:id => @user.xmpp_jid+'@'+@@xmpp_host, :psword => @user.xmpp_pw,
                     :host => @@xmpp_host, :port => @@xmpp_port, 
                     :node_service => "pubsub.#{@@xmpp_host}"}

      if NodeHelper.new(params[:nodepath], client_info, true).deleteNode    
        puts "Node deleted successfully!"
        render :text => "OK - 200", :status => 200
        return
      else
        puts "Deleting node failed!"
        render :text => "Deleting node failed!", :status => 200
        return
      end

    rescue Exception => e
      puts "Error in deleting node!"
      render :text => "Error in deleting node!", :status => 200
      return
    end
  end
  
  
    
  ##########################################################################################
  #
  #     FLICKR STUFF
  #
  ##########################################################################################

  
  
  # Returns 200 - If auth token is present and valid
  #         401 - If problem authenticating user
  #         409 - If auth token not present or expired
  def flickrConnected
    
    begin

      if not @auth_user
        puts "Authentication failed!"
        render :text => "Unauthorized - 401", :status => 401
        return
      end

      # Authenticated user
      @user = @auth_user
         
      # Checks if user already has auth token for flickr
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "flickr"])
       
      # If user already had auth token
      if not si
        render :text => "No access token for Flickr was found!", :status => 401
        return
      end

      FlickRaw.api_key = @@flickr_api_key
      FlickRaw.shared_secret = @@flickr_secret

      flickr.access_token = si.auth_token
      flickr.access_secret = si.auth_secret
      
      login = flickr.test.login
      if login.username != si.s_username
        raise Exception.new("Problem with authentication")
      end      
        
    rescue Exception => e
      putsE(e)
      render :text => "Error, couldn't find access token to Flickr': #{e.to_s}", :status => 409
      return
    end
    
    render :text => "Flickr access token is valid.", :status => 200
    return
    
  end



  def flickrSettings
    
    begin
   
      if params["hide"] == "true"
        render :update do |page|
          page["flickr_settings"].replace_html :partial => 'flickr_settings'
        end
        return
      end
     
      if not session[:username]
        puts "db_login"
        redirect_to :action => "login", :controller => "user"
        return
      else
        @user = User.find_by_username(session[:username]) 
      end
    
      si = ServiceInformation.find_by_user_id_and_service_type(@user.id, "flickr")
  
      @flickr_data = si
      
      # Initialize FlickRaw
      FlickRaw.api_key = @@flickr_api_key
      FlickRaw.shared_secret = @@flickr_secret
      
      @flickr_url = nil

      if @flickr_data == nil
        # User does not yet have auth_token
        
        # Use FlickRaw to get authorization url
        token = flickr.get_request_token(:oauth_callback => "#{@@http_host}/flickr_callback")
        @flickr_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'write')
        
        # Save the request token and secret
        flickr_auth = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                   :service_type => "flickr_auth")                                                              
        flickr_auth.update_attribute(:auth_token, token['oauth_token'])
        flickr_auth.update_attribute(:auth_secret, token['oauth_token_secret'] )
          
      else
      
  
        # Ensures that user has virtual_container called: flickr_container
        VirtualContainerManager.new(@user, "flickr_container")
              
        # List of users containers
        @virtualUserDevices = Device.find_all_by_user_id_and_dev_type(@user.id, "virtual_container")

        flickr.access_token = si.auth_token
        flickr.access_secret = si.auth_secret
  
        login = flickr.test.login
        if login.username != si.s_username
          raise Exception.new("Problem with authentication")
        end
       
      end
    rescue Exception => e
      putsE(e)
    end      

    render :update do |page|
      page["flickr_settings"].replace_html :partial => 'flickr_settings'
    end
  end
  
  
  
  # Convert request token to auth_token.
  # Parameters: authentication parameters
  #             'auth_code' - received from Flickr
  # Returns: 201 - Success
  #          409 - Failed
  def flickr_callback

    begin     
      
      if not session[:username]
        render :text => "Error, failed to authenticate user!", :status => 401
        return
      end
      
      @user = User.find_by_username(session[:username])
  
      if @user == nil
        raise Exception.new("Failed to find the user!")
      end
  
      if not params["oauth_verifier"]
        raise Exception.new("parameter 'auth_code' not found!")        
      end
      
      
      flickr_auth = ServiceInformation.find_by_user_id_and_service_type(@user.id, "flickr_auth")                                                              

      if not flickr_auth
        raise Exception.new("Flickr authentication information not found on the server.")
      end

      # Initialize FlickRaw
      FlickRaw.api_key = @@flickr_api_key
      FlickRaw.shared_secret = @@flickr_secret
       
      flickr.get_access_token(flickr_auth.auth_token, flickr_auth.auth_secret, params["oauth_verifier"])
      login = flickr.test.login
      puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}"

      # Put the flickr token and secret to database
      flickr_si = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                :service_type => 'flickr',
                                                                                :auth_token => flickr.access_token,
                                                                                :auth_secret => flickr.access_secret,
                                                                                :s_user_id => login.id,
                                                                                :s_username => login.username)
      
      # Remove the temporary 'flickr_auth' from database, since it is no longer needed
      puts "user id: #{@user.id}"
      sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "flickr_auth"])
      sis.each do |si|
        si.delete
      end

    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
    
  
    redirect_to "/user/#{session[:username]}/settings"
    return         
  end
  
  
  
  # A way for client programs to link Flickr with VisualREST, without the need of going to VisualREST web-page
  def flickr_client_authorization
    
    begin
      if not params[:username]
        render :text => "Error with username", :status => 409
        return
      end
      
      @user = User.find_by_username(params[:username])
          
      # Initialize FlickRaw
      FlickRaw.api_key = @@flickr_api_key
      FlickRaw.shared_secret = @@flickr_secret          
          
      # Use FlickRaw to get authorization url
      token = flickr.get_request_token(:oauth_callback => "#{@@http_host}/user/"+params[:username]+"/flickr_client_callback")
      @flickr_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'write')
          
      # Save the request token and secret
      flickr_auth = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                     :service_type => "flickr_auth")                                                              
      flickr_auth.update_attribute(:auth_token, token['oauth_token'])
      flickr_auth.update_attribute(:auth_secret, token['oauth_token_secret'] )        
        
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end

    puts @flickr_url
    redirect_to @flickr_url
    return

  end
  
  
  # Client programs authorization to Flickr account is directed to here.
  # Convert request token to auth_token.
  # Parameters: authentication parameters
  #             'auth_code' - received from Flickr
  # Returns: 201 - Success
  #          409 - Failed
  def flickr_client_callback

 
    begin     
      
      if not params[:username]
        render :text => "Error, failed to authenticate user!", :status => 401
        return
      end
      
      @user = User.find_by_username(params[:username])
  
      if @user == nil
        raise Exception.new("Failed to find the user!")
      end
  
      if not params["oauth_verifier"]
        raise Exception.new("parameter 'auth_code' not found!")        
      end
      
      
      flickr_auth = ServiceInformation.find_by_user_id_and_service_type(@user.id, "flickr_auth")                                                              

      if not flickr_auth
        raise Exception.new("Flickr authentication information not found on the server.")
      end

      # Initialize FlickRaw
      FlickRaw.api_key = @@flickr_api_key
      FlickRaw.shared_secret = @@flickr_secret
       
      flickr.get_access_token(flickr_auth.auth_token, flickr_auth.auth_secret, params["oauth_verifier"])
      login = flickr.test.login
      puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}"

      # Put the flickr token and secret to database
      flickr_si = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                :service_type => 'flickr',
                                                                                :auth_token => flickr.access_token,
                                                                                :auth_secret => flickr.access_secret,
                                                                                :s_user_id => login.id,
                                                                                :s_username => login.username)
      
      # Remove the temporary 'flickr_auth' from database, since it is no longer needed
      puts "user id: #{@user.id}"
      sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "flickr_auth"])
      sis.each do |si|
        si.delete
      end

    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
    
  
    render :text => "Authentication succesful, you can now return to the program you came here from!", :status => 201
    return 
 end
  
  

  def flickrDeleteToken
    
    if not session[:username]
      render :text => "User not logged in!", :status => 401
      return
    else
      @user = User.find_by_username(session[:username]) 
    end
    
    begin
      sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "flickr"])
      sis.each do |si|
        si.delete
      end
    rescue Exception => e
      putsE(e)
      render :text => "Failed to delete token!", :status => 500
      return
    end
    
    render :text => "Token deleted successfully!", :status => 200
    return
    
  end
  
  
  def flickrImportPhotos
  
    begin
      
      if not @auth_user
        raise Exception.new("Authentication failed!")
      end

      # Authenticated user
      @user = @auth_user
      
      if not params[:container_name]
        raise Exception.new("parameter 'container_name' missing.")
      end
      
      @virtualContainerManager = VirtualContainerManager.new(@user, params[:container_name])
      
      # This states what content we are importing from Flickr 
      if params[:privacy_filter] == "public"
        privacy_setting = "1"
      elsif params[:privacy_filter] == "private"
        privacy_setting = "5"
      else 
        raise Exception.new("parameter 'privacy_filter' value should be 'public'/'private'.")
      end
      
      
      si = ServiceInformation.find_by_user_id_and_service_type(@user.id, "flickr")                                                              

      if not si
        raise Exception.new("Flickr authentication information not found on the server.")
      end

      # Initialize FlickRaw
      FlickRaw.api_key = @@flickr_api_key
      FlickRaw.shared_secret = @@flickr_secret
       
      flickr.access_token = si.auth_token
      flickr.access_secret = si.auth_secret
  
      # Arguments for photo search on Flickr
      args = {}
      args[:privacy_filter] = privacy_setting
      args[:user_id] = si.s_user_id
    
      # Make the photo search
      photos = flickr.photos.search args
      
      @import_amount = photos.total

      # Go through all of the photos
      photos.each do |p|
        # get info about the photo
        info = flickr.photos.getInfo(:photo_id => p.id)

        # get essence of the photo
        url = FlickRaw.url_b(info)
        
        photo_url = URI.parse(url)
        
        photo = Net::HTTP.start(photo_url.host, photo_url.port) {|http|
            http.get(photo_url.path)
        } 
        
        photo_essence = photo.body
              
        filename = '/' + info.title + "_" + info.id + ".jpg"
              
        @virtualContainerManager.addFile(filename, photo_essence)
        
        # Save metadata to file
        @virtualContainerManager.addMetadata(filename, "url", url)
        @virtualContainerManager.addMetadata(filename, "origin", "flickr")
        @virtualContainerManager.addMetadata(filename, "flickr_id", info.id)
        
        if info.dates.taken != ""
          @virtualContainerManager.addMetadata(filename, "taken", info.dates.taken)
        end
        
        if info.description != ""
          @virtualContainerManager.addMetadata(filename, "description", info.description)
        end
        
        if info.tags != ""
          info.tags.each do |tag|
            @virtualContainerManager.addMetadata(filename, "tag", tag.to_s)
          end
        end         
                
        puts "File " + filename + " imported from Flickr."
     
      end
      
      # Make the commit of the files and metadatas
      @virtualContainerManager.commit
            
     rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
  
    render :text => "Imported #{@import_amount} photos from Flickr!", :status => 201
    return

  end
  
    
  def flickrPublishPhoto
    
    begin
      
      if not @auth_user
        raise Exception.new("Authentication failed!")
      end

      # Authenticated user
      @user = @auth_user
      
      caption = ""
      
      if params["file_uri"] 
        
        # The file_uri points to a file in VisualREST
        @devfile = getDevfileFromURI(params["file_uri"])
             
        @device = Device.find_by_id(@devfile.device_id)
             
        # Return true, if @user is authorized to devfile
        if not authorizedToDevfile(@devfile.id)
          raise Exception.new("Not authorized for the file!")
        end
        
        @blob = Blob.find_by_id(@devfile.blob_id)
        if @blob.uploaded == false
          raise Exception.new('The file is not uploded on the server')
        end
      else
          raise Exception.new("parameter file_uri was nil!")
      end
      
      if params["caption"]
        caption = params["caption"]
      end
      
    rescue Exception => e
      putsE(e)
      render :text => "Error in publishing to Flickr, problem with filepath!", :status => 409
      return
    end
      
      
    begin
      
      si = ServiceInformation.find_by_user_id_and_service_type(@user.id, "flickr")                                                              

      if not si
        render :text => "Error in publishing to Flickr, service information not found!", :status => 412
        return
      end

      if @devfile == nil || @blob == nil || @device == nil
        raise Exception.new("Devfile, device or blob not found!")
      end

      # Initialize FlickRaw
      FlickRaw.api_key = @@flickr_api_key
      FlickRaw.shared_secret = @@flickr_secret
       
      flickr.access_token = si.auth_token
      flickr.access_secret = si.auth_secret
  
    

      
      #url = URI.parse( @@fb_graph_uri + "/" + @fb_auth_token.s_user_id.to_s + "/photos")
      
      path_to_file = "public/devfiles/" + @devfile.device_id.to_s + "/" + @blob.blob_hash + "_" + @devfile.name
      
      if @device.dev_type == "virtual_container"
        
        # The file is on a virtual_container, Find the device's git repository
        if not File.exists?("private/#{@device.id}/.git")
          raise Exception.new("Git repository for the device was not found!")
        else
          @repo = Grit::Repo.new("private/#{@device.id}/.git")
        end
           
        # Get the blob data
        repoBlob = @repo.blob(@blob.blob_hash)
        if repoBlob == nil
          raise Exception.new("Blob was not found on the server")
        end
  
        path_to_file = "private/#{@device.id}#{@devfile.path}#{@devfile.name}"
        if not (File.exists?("private/#{@device.id}#{@devfile.path}") && File.directory?("private/#{@device.id}#{@devfile.path}"))
          FileUtils.mkdir_p("private/#{@device.id}#{@devfile.path}")      
        end 
        # Save from git to a file in path 'path_to_file'
        File.open(path_to_file, "wb") { |f|   
          f.write(repoBlob.data)
        }
      end
        
      # Upload the photo to Flickr
      photos = flickr.upload_photo path_to_file, :title => @devfile.name, :description => caption

      info = flickr.photos.getInfo(:photo_id => photos)
      urli = FlickRaw.url_b(info) # => "http://farm3.static.flickr.com/2485/3839885270_6fb8b54e06_b.jpg"


      # Add metadata: FLICKR_ID
      type = MetadataType.find_by_name("flickr_id")
      value = photos
  
      metadata = Metadata.find(:first, :conditions => ['metadata_type_id = ? and devfile_id = ?', type.id, @devfile.id])
      if metadata == nil
        metadata = Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(value, nil, @devfile.id, type.id)
      else
        metadata.update_attribute(:value, value)
      end
  
      # Add metadata: URL
      type = MetadataType.find_by_name("url")
      value = urli
  
      metadata = Metadata.find(:first, :conditions => ['metadata_type_id = ? and devfile_id = ?', type.id, @devfile.id])
      if metadata == nil
        metadata = Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(value, nil, @devfile.id, type.id)
      else
        metadata.update_attribute(:value, value)
      end



      if @device.dev_type == "virtual_container"
        # Delete the essence that was saved from git to the disk
        begin
          if File.exists?(path_to_file)
            FileUtils.rm_f(path_to_file)
            puts "deleted the essence that is still stored in git.."
          else
            puts "Essence not found..."
          end
        rescue => e
          puts "Error deleting essence: #{e}"
        end
      end
  
  
  
  
      

            
     rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
  
    render :text => "Published photo to Flickr", :status => 200
    return
    
   
  end
  
  

  
  
  ##########################################################################################
  #
  #     FACEBOOK STUFF
  #
  ##########################################################################################
  
  
  
  def facebookSettings
    
    if params["hide"] == "true"
      render :update do |page|
        page["facebook_settings"].replace_html :partial => 'facebook_settings'
      end
      return
    end
    
    if not session[:username]
      redirect_to :action => "login", :controller => "user"
      return
    else
      @user = User.find_by_username(session[:username]) 
    end


    # Ensures that user has virtual_container called: facebook_container
    VirtualContainerManager.new(@user, "facebook_container")

    # User's virtual containers
    @v_containers = @user.devices.find(:all, :conditions => ["dev_type = ?", "virtual_container"])
    
    # Checks if user already has auth token for facebook
    si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "facebook"])
    if si
      @fb_auth_token = si
    else
      @fb_auth_token = nil
    end
    
    # Get user's photo albums from facebook
    @photo_albums = {}
    if @fb_auth_token
      
      begin
          path = "/me/albums?access_token=#{@fb_auth_token.auth_token}"
          res = HttpRequest.new(:get, path).send(@@fb_graph_uri)
          
          photo_albums = JSON.parse(res.body)
          photo_albums = photo_albums["data"]

          photo_albums.each do |album|
            @photo_albums.merge!({album["name"] => album["id"]})
          end

      rescue Exception => e
        putsE(e)
      end

    else
      # URL where user gives access to Facebook account
      @my_url = "#{@@http_host}/facebook_callback"
      @facebook_authentication_url = "https://www.facebook.com/dialog/oauth?client_id=" + @@fb_app_id + "&redirect_uri=" + @my_url + "&scope=email,read_stream,user_photos,user_videos,friends_photos,friends_videos,user_events,friends_events,read_friendlists,offline_access,publish_stream"
    end
    
    render :update do |page|
      page["facebook_settings"].replace_html :partial => 'facebook_settings'
    end
    return 
  end
  
  
  
  
  #
  #   - Gets authentication token from facebook. 
  #   - Redirects to settings page when successful.
  #   - Returns 409 if errors occur
  def facebook_callback

    begin
      
      @my_url = "#{@@http_host}/facebook_callback"
      
      if not session[:username]
        redirect_to :action => "login", :controller => "user"
        return
      else
        @user = User.find_by_username(session[:username]) 
      end
      
      if not params["code"] or params["code"].empty?
        raise Exception.new("Error with parameters!")
        
      else
        
        code = params["code"]  
        token_path = "/oauth/access_token?client_id=" + @@fb_app_id + "&redirect_uri=" + @my_url + "&client_secret=" + @@fb_app_secret + "&code=" + code
        res = HttpRequest.new(:get, token_path).send(@@fb_graph_uri)
        
        # If token was received
        if res and res.code == "200"
    
          splitted = res.body.split('&');
          
          @access_token = splitted[0]
  
          token = @access_token.sub('access_token=', '')
          
          # Gets user info
          res = HttpRequest.new(:get, "/me?#{@access_token}").send(@@fb_graph_uri)
          user_info = JSON.parse(res.body)

          s_user_id = user_info["id"]
          s_username = user_info["name"]
          
          if s_user_id and token
            # Facebook does not have auth_secret, only auth_token
            ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                          :service_type => "facebook", 
                                                                          :s_user_id => s_user_id, 
                                                                          :auth_token => token,
                                                                          :s_username => s_username)
          else
            raise Exception.new("Error could not fetch token!")
          end
  
        else
          raise Exception.new("Could not get fb auth token..")
        end
        
      end
      
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
      
    redirect_to "/user/#{session[:username]}/settings"
    return
 end  
  
  
  
  # A way for client programs to link Facebook with VisualREST, without the need of going to VisualREST web-page
  def facebook_client_authorization
    
    if not params[:username]
      render :text => "Error with username", :status => 409
      return
    end
        
    # URL where user gives access to Facebook account
    @my_url = "#{@@http_host}/user/"+params[:username]+"/facebook_client_callback"
    
    @facebook_authentication_url = "https://www.facebook.com/dialog/oauth?client_id=" + @@fb_app_id + "&redirect_uri=" + @my_url + "&scope=email,read_stream,user_photos,user_videos,friends_photos,friends_videos,user_events,friends_events,read_friendlists,offline_access,publish_stream"

    redirect_to @facebook_authentication_url
    return

  end
  
  
  # Client programs authorization to Facebook account is directed to here.
  #   - Gets authentication token from facebook. 
  #   - Returns 409 if errors occur
  def facebook_client_callback

    begin
      
      if not params[:username]
        render :text => "Error with username", :status => 409
        return
      end
        
      # URL where user gives access to Facebook account
      @my_url = "#{@@http_host}/user/"+params[:username]+"/facebook_client_callback"
        
      @user = User.find_by_username(params[:username]) 
      
      
      if not params["code"] or params["code"].empty?
        raise Exception.new("Error with parameters!")
        
      else
        
        code = params["code"]  
        token_path = "/oauth/access_token?client_id=" + @@fb_app_id + "&redirect_uri=" + @my_url + "&client_secret=" + @@fb_app_secret + "&code=" + code
        res = HttpRequest.new(:get, token_path).send(@@fb_graph_uri)
        
        # If token was received
        if res and res.code == "200"
    
          splitted = res.body.split('&');
          
          @access_token = splitted[0]
  
          token = @access_token.sub('access_token=', '')
          
          # Gets user info
          res = HttpRequest.new(:get, "/me?#{@access_token}").send(@@fb_graph_uri)
          user_info = JSON.parse(res.body)

          s_user_id = user_info["id"]
          s_username = user_info["name"]
          
          if s_user_id and token
            # Facebook does not have auth_secret, only auth_token
            ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                          :service_type => "facebook", 
                                                                          :s_user_id => s_user_id, 
                                                                          :auth_token => token,
                                                                          :s_username => s_username)
          else
            raise Exception.new("Error could not fetch token!")
          end
  
        else
          raise Exception.new("Could not get fb auth token..")
        end
        
      end
      
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
      
    render :text => "Authentication succesful, you can now return to the program you came here from!", :status => 201
    return
 end  
  
  
  
  
  
  #
  #   Deletes the access token of facebook
  #
  def facebookDeleteToken
    
    if not session[:username]
      render :text => "User not logged in!", :status => 401
      return
    else
      @user = User.find_by_username(session[:username]) 
    end
    
    begin
      sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "facebook"])
      sis.each do |si|
        si.delete
      end
    rescue Exception => e
      putsE(e)
      render :text => "Failed to delete token!", :status => 500
      return
    end
    
    render :text => "Token deleted successfully!", :status => 200
    return
  end
  
  

  
  # Publish a photo from the server to Facebook
  # Parameters: 'file_uri' - uri to the photo in the server
  #              authentication parameters
  # Returns: 200 - Published photo to Facebook
  #          401 - Authentication failed
  #          409 - Error
  #          412 - Service authentication params not found
  def facebookPublishPhoto

    if not @auth_user
      puts "Authentication failed!"
      render :text => "Unauthorized - 401", :status => 401
      return
    end
    
    # Authenticated user
    @user = @auth_user

    caption = ""
     
    begin

      if params["file_uri"] 
        
        # The file_uri points to a file in VisualREST
        @devfile = getDevfileFromURI(params["file_uri"])
             
        @device = Device.find_by_id(@devfile.device_id)
             
        # Return true, if @user is authorized to devfile
        if not authorizedToDevfile(@devfile.id)
          raise Exception.new("Not authorized for the file!")
        end
        
        @blob = Blob.find_by_id(@devfile.blob_id)
        if @blob.uploaded == false
          raise Exception.new('The file is not uploded on the server')
        end
      else
          raise Exception.new("parameter file_uri was nil!")
      end
      
      if params["caption"]
        caption = params["caption"]
      end
      
    rescue Exception => e
      putsE(e)
      render :text => "Error in publishing to Facebook, problem with filepath!", :status => 409
      return
    end
    
   
    
    begin
      # Checks that user already has auth token for facebook
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "facebook"])
      if si
        @fb_auth_token = si
      else
        render :text => "Error in publishing to Facebook, couldn't find service information'!", :status => 412
        return
      end
     
      if @devfile == nil || @blob == nil || @device == nil
        raise Exception.new("Devfile, device or blob not found!")
      end
      
      if @devfile.filetype.include?("video")
        url = URI.parse( @@fb_graph_uri + "/" + @fb_auth_token.s_user_id.to_s + "/videos")        
      else
        url = URI.parse( @@fb_graph_uri + "/" + @fb_auth_token.s_user_id.to_s + "/photos")        
      end
      
      
      path_to_file = "public/devfiles/" + @devfile.device_id.to_s + "/" + @blob.blob_hash + "_" + @devfile.name
      
      if @device.dev_type == "virtual_container"
        
        # The file is on a virtual_container, Find the device's git repository
        if not File.exists?("private/#{@device.id}/.git")
          raise Exception.new("Git repository for the device was not found!")
        else
          @repo = Grit::Repo.new("private/#{@device.id}/.git")
        end
           
        # Get the blob data
        repoBlob = @repo.blob(@blob.blob_hash)
        if repoBlob == nil
          raise Exception.new("Blob was not found on the server")
        end
  
        path_to_file = "private/#{@device.id}#{@devfile.path}#{@devfile.name}"
        if not (File.exists?("private/#{@device.id}#{@devfile.path}") && File.directory?("private/#{@device.id}#{@devfile.path}"))
          FileUtils.mkdir_p("private/#{@device.id}#{@devfile.path}")      
        end 
        # Save from git to a file in path 'path_to_file'
        File.open(path_to_file, "wb") { |f|   
          f.write(repoBlob.data)
        }
      end
    
      
      File.open(path_to_file) do |photo|

        req = Net::HTTP::Post::Multipart.new( url.path,
          "source" => UploadIO.new(photo, @devfile.filetype, @devfile.name), "access_token" => @fb_auth_token.auth_token,
          "caption" => caption )
         
        http = Net::HTTP.new(url.host, url.port)
        if url.scheme == 'https'
          http.use_ssl = true
          http.ssl_timeout = 2  
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        
        res = http.start {|ht| ht.request(req) }

      
        # Check if the file is added to Facebook from response
        if res.code.to_s != "200"
          raise Exception.new("Could not upload to Facebook.")
        else
          # Add metadata to the file on server
          type = MetadataType.find_by_name("facebook_id")
          value = JSON.parse(res.body.to_s)["id"]
  
          metadata = Metadata.find(:first, :conditions => ['metadata_type_id = ? and devfile_id = ?', type.id, @devfile.id])
          if metadata == nil
            metadata = Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(value, nil, @devfile.id, type.id)
          else
            metadata.update_attribute(:value, value)
          end
  
        end
      end


      if @device.dev_type == "virtual_container"
        # Delete the essence that was saved from git to the disk
        begin
          if File.exists?(path_to_file)
            FileUtils.rm_f(path_to_file)
            puts "deleted the essence that is still stored in git.."
          else
            puts "Essence not found..."
          end
        rescue => e
          puts "Error deleting essence: #{e}"
        end
      end


    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end 
  
    render :text => "Succesfully published photo to Facebook!", :status => 200
    return
  end
  
  
  # Write on user's Facebook wall
  # Parameters: 'message' - Message that will be published on the user's wall
  #              authentication parameters
  # Returns: 200 - Published message on Facebook wall
  #          401 - Authentication failed
  #          409 - Error
  def facebookWriteOnWall

    if not @auth_user
      puts "Authentication failed!"
      render :text => "Unauthorized - 401", :status => 401
      return
    end
    
    # Authenticated user
    @user = @auth_user

     
    begin

      if params["message"] 
        @message = params["message"]
      else
          raise Exception.new("parameter message was nil!")
      end
      
    rescue Exception => e
      putsE(e)
      render :text => "Error in publishing to Facebook, problem with 'message'!", :status => 409
      return
    end
    
   
    begin
      # Checks that user already has auth token for facebook
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "facebook"])
      if si
        @fb_auth_token = si
      else
        raise Exception.new("Error, couldn't find service information for Facebook account")
      end
     puts "tee kutsu"
      path = "/" + @fb_auth_token.s_user_id.to_s + "/feed?access_token=#{@fb_auth_token.auth_token}&message=#{CGI::escape(@message)}"

          puts path

      res = HttpRequest.new(:post, path).send(@@fb_graph_uri)
               puts res.code
               puts res.body
      # Check if the request was successful
      if res.code.to_s != "200"
        raise Exception.new("Problem writing on Facebook wall.")
      end

    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end 
  
    render :text => "Succesfully wrote on Facebook wall!", :status => 200
    return
  end
  
  
  
  
  
  
  # POST to /user/:username/facebookImportAlbum
  # Parameters: - Authentication parameters
  #             - 'container_name' - container where the files will be imported to
  #             - 'album_id' - ID of the album to be imported
  # Returns: - 200 - Success
  #          - 409 - Failure
  def facebookImportAlbum
    
    begin
    
      puts "facebookImportAlbum"
    
      if not @auth_user
        raise Exception.new("Problem authenticating!")
      end
      
      @user = @auth_user


      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "facebook"])
      if not si
        raise Exception.new("Service information for Facebook was not found!")
      end
      
      @fb_auth_token = si.auth_token
    
      if params["container_name"]
        @container_name = params["container_name"]
      else
        raise Exception.new("Parameter 'container_name' was not found!")
      end
    
      virtualContainerManager = VirtualContainerManager.new(@user, @container_name)

      if params['album_id']
        @album_id = params['album_id']
      else
        raise Exception.new("Parameter 'import_album_id' was not found!")
      end


      puts "Container name: #{@container_name}. Album id: #{@album_id}."
          
      # Album information
      res = HttpRequest.new(:get, "/#{@album_id}?access_token=#{@fb_auth_token}").send(@@fb_graph_uri)
      puts res.code
      if res.code.to_s != "200"
        raise Exception.new("Could not find album info from Facebook!")
      end

      album_info = JSON.parse(res.body)
      #puts JSON.pretty_generate(JSON.parse(res.body))      
      
      # Photos of the album
      res = HttpRequest.new(:get, "/#{@album_id}/photos?access_token=#{@fb_auth_token}").send(@@fb_graph_uri)
      
      counter = 0
      
      if res.code == "200" and res.body != ""
              
        album_photos = JSON.parse(res.body)["data"]
        album_photos.each do |photo|

          # From this url the photo will be downloaded to VisualREST
          photo_url = URI.parse(photo["source"].to_s)
         
          photo_essence = HttpRequest.new(:get, photo_url.path).send("http://#{photo_url.host}").body
    
          # The picture name is composed of "album name" and "photo id"
          pic_name = '/' + album_info["name"] + "_#{photo["id"]}.jpg"
          pic_name = pic_name.sub(' ', '_')
          
          virtualContainerManager.addFile(pic_name, photo_essence)
          
          virtualContainerManager.addMetadata(pic_name, "origin", "facebook")
          
          if photo["name"]
            virtualContainerManager.addMetadata(pic_name, "description", photo["name"].to_s)
          end
          
          if photo["source"]
            virtualContainerManager.addMetadata(pic_name, "url", photo["source"].to_s)
          end

          if photo["id"]
            virtualContainerManager.addMetadata(pic_name, "facebook_id", photo["id"].to_s)
          end

          counter += 1

        end
      end
      
      virtualContainerManager.commit
      d = virtualContainerManager.getDeviceObject

    rescue Exception => e
      putsE(e)
      render :text => "Error importing album from Facebook: #{e.to_s}", :status => 409
      return
    end

    render :text => "Imported #{counter} photos from Facebook to: #{@container_name}", :status => 200
    return
    
  end

    


  def facebookConnected
    
    begin
      if not @auth_user
        raise Exception.new("Authentication failed!")
      end
      
      # Authenticated user
      @user = @auth_user
      
      # Find Service Information for Facebook
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "facebook"])
      if not si
        render :text => "No access token for Facebook was found!", :status => 401
        return
      end
      
      # Test that the auth_token is still active
      path = "/me?access_token=#{si.auth_token}"
          
      res = HttpRequest.new(:get, path).send(@@fb_graph_uri)
      
      if res.code.to_s != "200"
        raise Exception.new("Access token might be old!")
      end
    rescue Exception => e
      putsE(e)
      render :text => "Error, couldn't find access token to Facebook': #{e.to_s}", :status => 409
      return
    end  
    
    puts "Facebook access token is valid."
    render :text => "Facebook access token is valid.", :status => 200
    return
    
  end

  
  
  #######
  ## TESTING STUFF
  #######
  def fbTestingStuff
    # Nothing needed here.
    # Loads the testing window.
    
  end
  
  
  def fbTestingStuff2
    
    

    if not session[:username]
      redirect_to :action => "login", :controller => "user"
      return
    else
      @user = User.find_by_username(session[:username]) 
    end


    # Ensures that user has virtual_container called: facebook_container
    VirtualContainerManager.new(@user, "facebook_container")

    # User's virtual containers
    @v_containers = @user.devices.find(:all, :conditions => ["dev_type = ?", "virtual_container"])
    
    # Chacks if user already has auth token for facebook
    si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "facebook"])
    if si
      @fb_auth_token = si
    else
      @fb_auth_token = nil
    end
    # Get user's photo albums from face book

   # @photo_albums = {}
    if @fb_auth_token
      # Photo albums
      begin
        
        # Must match with '/xxx/xxx' or '/xxx'
        if params[:fb_graph_test] && ( params[:fb_graph_test] =~ /^\/[\w]+$/ || params[:fb_graph_test] =~ /^\/[\w]+\/[\w]+$/ )
          
          @fb_query_param = params[:fb_graph_test]
          @fb_previous_request = nil
          if params["fb_previous_request"]
            @fb_previous_request = params["fb_previous_request"]
          end
          
          puts "HAETTIIN GRAPHISTA JOTAIN!!!"
          path = params[:fb_graph_test] + "?access_token=#{@fb_auth_token.auth_token}&metadata=1"
        
          response = HttpRequest.new(:get, path).send(@@fb_graph_uri)
          
        
          
          @fb_the_response_for_test = ""
          @connection_list = {}
          @album_list = {}
          @object_info = {}
          @fb_object_type = nil
          @object_connections = {}
          @fb_picture_object = nil

      
               #   @fb_the_response_for_test += JSON.pretty_generate(JSON.parse(response.body))
                  puts JSON.pretty_generate(JSON.parse(response.body))
      
          # Connections - if the query was made to a second level object
          if params[:fb_graph_test] =~ /^\/[\w]+\/[\w]+$/
            @fb_object_type = params[:fb_graph_test].split('/')[2]
            
            connections = JSON.parse(response.body)
            connections = connections["data"]
            
            if @fb_object_type == "albums"
              connections.each do |connection|
                @album_list.merge!({ connection["id"] => { "name" => connection["name"], "from" => connection["from"]["name"], "fromid" => connection["from"]["id"]}})
              end  
            
            elsif      
              connections.each do |connection|
                @connection_list.merge!({ connection["id"] => connection["name"]})
              end
            end
            
            
          
          # Info about an object
          elsif params[:fb_graph_test] =~ /^\/[\w]+$/
            me = JSON.parse(response.body)
            me.each do |x,y|
              # Hide these for now, from 'user'
              if x == "metadata" || x == "timezone" || x == "locale" || x == "verified" 

              # Hide these for now, from 'photo'
              elsif x == "comments" || x == "images" || x == "likes" || x == "position" ||
                x == "icon" || x == "source" || x == "height" || x == "width"
                
              # Hide these for now, from 'album'
              elsif x == "can_upload" || x == "privacy"
                
              elsif x == "picture"
                @fb_picture_object = y

              elsif x == "from"
                @object_info.merge!({ x => {"id" => y["id"], "user" => y["name"] }})
                                 
              elsif x == "type"
                @fb_object_type = y
                
              else
                @object_info.merge!({x => y})
              end
            end

          else
            @fb_the_response_for_test += JSON.pretty_generate(JSON.parse(response.body))
#            puts @fb_the_response_for_test
          end
          
          
          if @fb_object_type == "user"
            @object_connections.merge!({ "Photo albums" => params[:fb_graph_test] + "/albums",
                                       # "events" => params[:fb_graph_test] + "/events",
                                         "feed" => params[:fb_graph_test] + "/feed",
                                         "friends" => params[:fb_graph_test] + "/friends", 
                                        # "mutualfriends" => params[:fb_graph_test] + "/mutualfriends",
                                         "Photos the user is tagged in" => params[:fb_graph_test] + "/photos",
                                         "Profile picture" => params[:fb_graph_test] + "/picture",
                                         "Posts by the user" => params[:fb_graph_test] + "/posts"})
          
          elsif @fb_object_type == "album"
            @object_connections.merge!({ "Photos of the album" => params[:fb_graph_test] + "/photos"})
          end
          
          
        else
          @fb_the_response_for_test = "You haven't made a test yet!"
        end
        
      rescue Exception => e
        putsE(e)
                 
        if e.to_s[0..2] == "302"
          
          @fb_the_response_for_test = "<br />"
          @kuva_prkl = e.to_s[5..-1]
          @fb_object_type = "User's profile picture"
          
        else
          @fb_the_response_for_test = "ERROR! Problem with faulty parameter or ACCESS TOKEN EXPIRED?  Token is renewed in settings: <a href='/user/"+ session[:username] +"/settings'>Settings</a><br /> Delete the Facebook token and get a new one."
        end 
                 
        


      end

    end
    
    
    render :update do |page|
      page["fb_response_for_test"].replace_html :partial => 'fb_response_for_test'
    end
    return 


  end#### END TESTING STUFF
     ######################
     
     


##################################################################################
#
#    Dropbox stuff
#
##################################################################################

  def dropboxUpload
    
          
    begin
  
      if not @auth_user
        puts "Authentication failed!"
        render :text => "Unauthorized - 401", :status => 401
        return
      end
      
      # Authenticated user
      @user = @auth_user
         

      # Find the file that will be uploaded
     
      if params["file_uri"] 
        
        file_uri = params["file_uri"]
        # The file_uri points to a file in VisualREST
        @devfile = getDevfileFromURI(file_uri)
             
        @device = Device.find_by_id(@devfile.device_id)
             
        # Return true, if @user is authorized to devfile
        if not authorizedToDevfile(@devfile.id)
          raise Exception.new("Not authorized for the file!")
        end
        
        @blob = Blob.find_by_id(@devfile.blob_id)
        if @blob.uploaded == false
          raise Exception.new('The file is not uploded on the server')
        end
      else
          raise Exception.new("parameter file_uri was nil!")
      end


      # The path where to upload in dropbox
      if params["dropbox_path"]
        dropbox_path = params["dropbox_path"]
        if dropbox_path[0,1] != "/"
          dropbox_path = "/" + dropbox_path
        end
      else
        raise Exception.new("parameter dropbox_full_path was nil!")
      end
      
      begin
        # Open the dropboxhelper. If dropbox auth_token is not already saved, an exception is thrown    
        helper = DropboxHelper.new(@user)
      rescue Exception => e
        putsE(e)
        render :text => "Error uploading file to Dropbox: #{e.to_s}", :status => 412
        return
      end
        
      
      # Upload the file. If there is an error, exception will be thrown and later it will be catched.  
      info = helper.uploadFile(dropbox_path, file_uri)
      
   
    rescue Exception => e
      putsE(e)
      render :text => "Error uploading file to Dropbox: #{e.to_s}", :status => 409
      return
    end
    
    render :text => "File uploaded to Dropbox.", :status => 200
    return
    
  end
  
  
  def dropboxSettings
    
    begin
      
      if params["hide"] == "true"
        render :update do |page|
          page["dropbox_settings"].replace_html :partial => 'dropbox_settings'
        end
        return 
      end

      if not session[:username]
        puts "db_login"
        redirect_to :action => "login", :controller => "user"
        return
      else
        @user = User.find_by_username(session[:username]) 
      end
    
      sql = "SELECT user_dropbox_contents.id as ud_id, 
                    user_dropbox_contents.path as path, 
                    devices.dev_name as dev_name
            FROM user_dropbox_contents, devices
            WHERE user_dropbox_contents.content_type = 'root' AND
                  user_dropbox_contents.user_id = #{@user.id} AND 
                  user_dropbox_contents.device_id = devices.id"
      @folders_and_containers = UserDropboxContent.find_by_sql(sql)
    
    
    
    
      # Ensures that user has virtual_container called: dropbox_container
      VirtualContainerManager.new(@user, "dropbox_container")
  
      # User's virtual containers
      @v_containers = @user.devices.find(:all, :conditions => ["dev_type = ?", "virtual_container"])
      
      # Checks if user already has auth token for dropbox
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "dropbox"])
      
      
      # If user already had auth token, finds dropbox root folders
      @db_dirs = []
      if si

        @db_auth_token = si        
      
        helper = DropboxHelper.new(@user)
          
        info = helper.getUserInfo
        if info == "ERROR"
          raise Exception.new("Problem with getting user info from Dropbox")
        end
        @db_authenticated = "true"
          
        if info and info != nil
          @db_display_name = info["display_name"]
          @db_email = info["email"]
          @db_uid = info["uid"]
        end        
          
        # The changed value is not used here. It is used when looking requesting for changes in a directory
        metadatas= helper.getMetadatas("/")
#        puts JSON.pretty_generate(metadatas)
          
        metadatas["contents"].each do |content|
          if content["is_dir"]
            @db_dirs << content["path"]
          #  puts "Folder: #{content['path']}"
          #  puts "      -Modified: #{content['modified']}"
          #  puts "      -rev: #{content['rev']}"  
            end
        end
          
          
      # Else user doesn't yet have auth token
      else

        @db_auth_token = nil

        # First get the token
        dropboxOAuthStep1
      
      end

    rescue Exception => e
      putsE(e)
    end
    
    
    render :update do |page|
      page["dropbox_settings"].replace_html :partial => 'dropbox_settings'
    end
    return 
  end
  
  
  def dropboxOAuthStep1
    
    begin

      timestamp = Time.now.to_i
      nonce = rand(10 ** 30).to_s.rjust(30,'0')      
      path = "/1/oauth/request_token"
      
      params = "oauth_consumer_key=#{@@db_app_id}&oauth_nonce=#{nonce}&oauth_signature_method=PLAINTEXT" +
               "&oauth_timestamp=#{timestamp}&oauth_version=1.0"
      
      signature =  @@db_app_secret + "%26"            
                 
      head_params = 'OAuth realm="https://api.dropbox.com/1/oauth/request_token", oauth_consumer_key="' + @@db_app_id + '", oauth_nonce="'+ nonce + '", oauth_signature_method="PLAINTEXT"' +
               ', oauth_signature="'+ signature +'", oauth_timestamp="'+ timestamp.to_s + '", oauth_version="1.0"'          

                 
      header = { 'Authorization' => head_params}
             
             
      ####################
      ###  OAUTH - STEP 1
      ####################
      res = HttpRequest.new(:post, path, {}, header, false).send(@@dropbox_host)
      
      if res.code.to_s != "200"
        raise Exception.new("#{res.code.to_s}, #{res.body.to_s}")
      end
      
      splitted = res.body.split('&')
      oauth_token_secret = splitted[0].split('=')[1]
      oauth_token = splitted[1].split('=')[1] 
      
      # Save the dropbox_authentication token and token_secret for later use
      dropbox_auth = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                   :service_type => "dropbox_auth")                                                              
      dropbox_auth.update_attribute(:auth_token, oauth_token)#extra_1
      dropbox_auth.update_attribute(:auth_secret, oauth_token_secret ) #extra_2



      ##################
      ### OAUTH - URL for step 2
      ##################
      if @client_auth && @client_auth == true
        @dropbox_url = "https://www.dropbox.com/1/oauth/authorize?oauth_token=#{oauth_token}&oauth_callback=#{@@http_host}/user/"+@user.username+"/dropbox_client_callback&locale=en"
      else
        @dropbox_url = "https://www.dropbox.com/1/oauth/authorize?oauth_token=#{oauth_token}&oauth_callback=#{@@http_host}/dropbox_callback&locale=en"
      end
      
    rescue Exception => e
      putsE(e)
      render :text => "Error in fetching access token!", :status => 409
      return
    end
    
  end
  
  
  
  
  def dropbox_callback
    
      begin
        
      ##################
      ### OAUTH - step 3
      ##################
        puts "Dropbox OAUTH step 3"
        if params["oauth_token"] && params["oauth_token"] != nil && params["uid"] && params["uid"] != nil
          
          received_oauth_token = params["oauth_token"]
          received_oauth_uid = params["uid"]
          
          # Make sure the user has 'dropbox_auth' process begun
          @user = User.find_by_username(session[:username])
          si = ServiceInformation.find_by_user_id_and_service_type(@user.id, 'dropbox_auth')
          if si == nil || si.auth_secret == nil
            return
          end 
          
          nonce = rand(10 ** 30).to_s.rjust(30,'0')
          timestamp = Time.now.to_i
          signature = @@db_app_secret + "&" + si.auth_secret
          
          params = { "oauth_consumer_key" => @@db_app_id, 
                     "oauth_token" => received_oauth_token,
                     "oauth_signature_method" => "PLAINTEXT", 
                     "oauth_signature" => signature,
                     "oauth_timestamp" => timestamp,
                     "oauth_nonce" => nonce, 
                     "oauth_version" => "1.0"}
          
          
          path = "/1/oauth/access_token"
          res = HttpRequest.new(:post, path, params, nil, false).send(@@dropbox_host)

          if res.code.to_s != "200"
           raise Exception.new("#{res.code.to_s}, #{res.body.to_s}")
          end
          
          splitted = res.body.split('&')
          oauth_token_secret = splitted[0].split('=')[1]
          oauth_token = splitted[1].split('=')[1] 
          
                     
          
          # Put the dropbox token and secret to database
          dropbox_si = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                     :service_type => 'dropbox',
                                                                                     :auth_secret => oauth_token_secret,
                                                                                     :auth_token => oauth_token,
                                                                                     :s_user_id => received_oauth_uid)
          
          # Remove the temporary 'dropbox_auth' from database, since it is no longer needed
          sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "dropbox_auth"])
          sis.each do |si|
            si.delete
          end
                      
      end #if
      
    rescue Exception => e      
      putsE(e)
      render :text => "There was an error in step 3 of the Dropbox OAuth", :status => 409
      return  
    end
    
    redirect_to "/user/#{session[:username]}/settings"
    return
    
  end      

  
  # A way for client programs to link Dropbox with VisualREST, without the need of going to VisualREST web-page
  def dropbox_client_authorization
    
    begin
      if not params[:username]
        render :text => "Error with username", :status => 409
        return
      end
      
      @user = User.find_by_username(params[:username])
          
      @client_auth = true
          
      # Get OAuth token and url for authentication into '@dropbox_url'
      dropboxOAuthStep1        
        
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end

    redirect_to @dropbox_url
    return

  end
  
  
  # Client programs authorization to Dropbox account is directed to here.
  # Returns: 201 - Success
  #          409 - Failed
  def dropbox_client_callback

    begin
        
      ##################
      ### OAUTH - step 3
      ##################
        puts "Dropbox OAUTH step 3"
        if params["oauth_token"] && params["oauth_token"] != nil && params["uid"] && params["uid"] != nil
          
          received_oauth_token = params["oauth_token"]
          received_oauth_uid = params["uid"]
          
          # Make sure the user has 'dropbox_auth' process begun
          @user = User.find_by_username(params[:username])
          si = ServiceInformation.find_by_user_id_and_service_type(@user.id, 'dropbox_auth')
          if si == nil || si.auth_secret == nil
            return
          end 
          
          nonce = rand(10 ** 30).to_s.rjust(30,'0')
          timestamp = Time.now.to_i
          signature = @@db_app_secret + "&" + si.auth_secret
          
          params = { "oauth_consumer_key" => @@db_app_id, 
                     "oauth_token" => received_oauth_token,
                     "oauth_signature_method" => "PLAINTEXT", 
                     "oauth_signature" => signature,
                     "oauth_timestamp" => timestamp,
                     "oauth_nonce" => nonce, 
                     "oauth_version" => "1.0"}
          
          
          path = "/1/oauth/access_token"
          res = HttpRequest.new(:post, path, params, nil, false).send(@@dropbox_host)

          if res.code.to_s != "200"
           raise Exception.new("#{res.code.to_s}, #{res.body.to_s}")
          end
          
          splitted = res.body.split('&')
          oauth_token_secret = splitted[0].split('=')[1]
          oauth_token = splitted[1].split('=')[1] 
          
                     
          
          # Put the dropbox token and secret to database
          dropbox_si = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                     :service_type => 'dropbox',
                                                                                     :auth_secret => oauth_token_secret,
                                                                                     :auth_token => oauth_token,
                                                                                     :s_user_id => received_oauth_uid)
          
          # Remove the temporary 'dropbox_auth' from database, since it is no longer needed
          sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "dropbox_auth"])
          sis.each do |si|
            si.delete
          end
                      
      end #if
      
    rescue Exception => e      
      putsE(e)
      render :text => "There was an error in step 3 of the Dropbox OAuth", :status => 409
      return  
    end
    
    render :text => "Authentication succesful, you can now return to the program you came here from!", :status => 201
    return
 end
  
  
  
  
  def dbCreateDirPoller
    
    begin
      @dir2poll = params["checked_dir"]
      puts "Dir to Poll: #{@dir2poll}"
      
      if not session[:username]
        puts "db_login"
        redirect_to :action => "login", :controller => "user"
        return
      else
        @user = User.find_by_username(session[:username]) 
      end
      
      # Ensures that user has the selected virtual container
      vM = VirtualContainerManager.new(@user, params["container_name"])
      
      dev_id = vM.getDeviceObject.id
      
      begin
        # Clears all the old content from the container
        dh = DeleteHelper.new(dev_id)
        dh.removeContent
        puts "Old content deleted!"
      rescue Exception => p
        putsE(p)
      end
      
      # Checks that user already has auth token for dropbox
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "dropbox"])
  
      dir2poll = UserDropboxContent.find_or_create_by_user_id_and_path_and_device_id_and_content_type(@user.id, @dir2poll, dev_id, "root")
      dir2poll.update_attribute(:root_dir_id, dir2poll.id)  
    rescue Exception => e
      putsE(e)
      render :text => "Error in creating folder poller", :status => 409
      return
    end
    
    #render :text => "Created folder poller", :status => 200
    redirect_to "/user/#{@user.username}/device/#{params["container_name"]}/files"
    return
  end
  
  
  def dbDeletePoller
    if not session[:username]
      render :text => "User not logged in!", :status => 401
      return
    else
      @user = User.find_by_username(session[:username]) 
    end
    
    
    begin
      sql = "SELECT * 
             FROM user_dropbox_contents
             WHERE user_id = #{@user.id} AND id = #{params[:ud_id]} OR 
                   user_id = #{@user.id} AND root_dir_id = #{params[:ud_id]}"
                   
      udcs = UserDropboxContent.find_by_sql(sql)
      udcs.each do |udc|
        puts "udc: #{udc.to_s}"
        
        udc.delete
      end
    rescue Exception => e
      putsE(e)
      render :text => "Failed to delete user dropbox content!", :status => 500
      return
    end
    
    render :text => "User dropbox contents successfully!", :status => 200
    return
  end
  
  
  
  #
  #   Deletes the access token of dropbox
  #
  def dropboxDeleteToken
    
    if not session[:username]
      render :text => "User not logged in!", :status => 401
      return
    else
      @user = User.find_by_username(session[:username]) 
    end
    
    begin
      sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "dropbox"])
      sis.each do |si|
        si.delete
      end
    rescue Exception => e
      putsE(e)
      render :text => "Failed to delete token!", :status => 500
      return
    end
    
    render :text => "Token deleted successfully!", :status => 200
    return
  end
  
  
  def dropboxConnected
      
    begin
  
      if not @auth_user
        puts "Authentication failed!"
        render :text => "Unauthorized - 401", :status => 401
        return
      end
      
      # Authenticated user
      @user = @auth_user
         
      # Checks if user already has auth token for dropbox
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "dropbox"])
       
      # If user already had auth token
      if not si
        render :text => "No access token for Dropbox was found!", :status => 401
        return
      end

      # Connect Dropbox and see if the token is valid
      helper = DropboxHelper.new(@user)
          
      info = helper.getUserInfo
      
      if info == "ERROR"
        raise Exception.new("Access token might be old!")
      end
      puts info


        
    rescue Exception => e
      putsE(e)
      render :text => "Error, couldn't find access token to Dropbox': #{e.to_s}", :status => 409
      return
    end
    
    render :text => "Dropbox access token is valid.", :status => 200
    return
  
  end
  
  
  
      ################################
      ####### TWITTER BEGINS #########
      ################################

  def twitterSettings
    
    begin
      
      # If user is closing the settings, nothing more needs to be done
      if params["hide"] == "true"
        render :update do |page|
          page["twitter_settings"].replace_html :partial => 'twitter_settings'
        end
        return
      end
      
      @twitter_authentication_url = 
      @twitter_authenticated = false
      
      if not session[:username]
        puts "twitter_login"
        redirect_to :action => "login", :controller => "user"
        return
      else
        @user = User.find_by_username(session[:username]) 
      end
      
      # Checks if user already has auth token for twitter
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "twitter"])
      
      
      # If user already had auth token
      if si
        @twitter_auth_token = true

        client = TwitterOAuth::Client.new(
                                    :consumer_key    => @@twitter_consumer_key,
                                    :consumer_secret => @@twitter_consumer_secret,
                                    :token           => si.auth_token,
                                    :secret          => si.auth_secret )
                               
        if client.authorized? == false
          raise Exception.new("Error: Problem connecting to Twitter with users information!")
        end

        @twitter_authenticated = true
        
        info = (client.info)
   #     puts JSON.pretty_generate(info)

        if info and info != nil
          
          @twitter_screen_name = info["screen_name"]
          @twitter_name = info["name"]
          @twitter_uid = info["id"]
          @twitter_statuses_count = info["statuses_count"]
        end        
 
          
      # Else user doesn't yet have auth token
      else

        #################
        ## OAuth - step 1
        #################
        client = TwitterOAuth::Client.new(
                                    :consumer_key => @@twitter_consumer_key,
                                    :consumer_secret => @@twitter_consumer_secret )
                                    
        request_token = client.request_token(:oauth_callback => @@http_host + "/twitter_callback")
        
        twitter_auth = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                   :service_type => "twitter_auth")                                                              
        twitter_auth.update_attribute(:auth_token, request_token.token)
        twitter_auth.update_attribute(:auth_secret, request_token.secret )

        
        @twitter_auth_token = nil


        #################
        ## OAuth - step 2
        #################
        # Request token from twitter and give user
        @twitter_authentication_url = request_token.authorize_url 
      
      end

    rescue Exception => e
      putsE(e)
    end
    
    
    render :update do |page|
      page["twitter_settings"].replace_html :partial => 'twitter_settings'
    end
    return 
  end



  def twitter_callback

        #################
        ## OAuth - step 3
        #################
    
      begin

        puts "Twitter OAUTH step 3"
        
        if params["oauth_token"] && params["oauth_token"] != nil && 
          params["oauth_verifier"] && params["oauth_verifier"] != nil
          
          if not session || session[:username]
            raise Exception.new("Error: Could not find user in session!")
          end
          
          # Make sure the user has 'twitter_auth' process begun
          @user = User.find_by_username(session[:username])
          
          si = ServiceInformation.find_by_user_id_and_service_type(@user.id, 'twitter_auth')
          
          if si == nil || si.auth_token == nil || si.auth_secret == nil
            raise Exception.new("Error: could not find twitter_auth information!")
          end 
          
          client = TwitterOAuth::Client.new(
                                    :consumer_key => @@twitter_consumer_key,
                                    :consumer_secret => @@twitter_consumer_secret )
          
          access_token =  client.authorize(
                            si.auth_token, 
                            si.auth_secret,
                            :oauth_verifier => params[:oauth_verifier] )
          
          
                     
          
          # Put the twitter token and secret to database
          twitter_si = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                     :service_type => 'twitter',
                                                                                     :auth_secret => access_token.secret,
                                                                                     :auth_token => access_token.token)
          
          # Remove the temporary 'twitter_auth' from database, since it is no longer needed
          puts "user id: #{@user.id}"
          sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "twitter_auth"])
          sis.each do |si|
            si.delete
          end
                      
      end #if
      
    rescue Exception => e      
      putsE(e)
      render :text => "There was an error in step 3 of the Twitter OAuth", :status => 409
      return  
    end
    
    redirect_to "/user/#{session[:username]}/settings"
    return 
  end



  # A way for client programs to link Twitter with VisualREST, without the need of going to VisualREST web-page
  def twitter_client_authorization
    
    begin
      if not params[:username]
        render :text => "Error with username", :status => 409
        return
      end
      
      @user = User.find_by_username(params[:username])
          
      #################
      ## OAuth - step 1
      #################
      client = TwitterOAuth::Client.new(
                                  :consumer_key => @@twitter_consumer_key,
                                  :consumer_secret => @@twitter_consumer_secret )
                                  
      request_token = client.request_token(:oauth_callback => @@http_host + "/user/" + @user.username + "/twitter_client_callback")
      
      twitter_auth = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                 :service_type => "twitter_auth")                                                              
      twitter_auth.update_attribute(:auth_token, request_token.token)
      twitter_auth.update_attribute(:auth_secret, request_token.secret )

      
      @twitter_auth_token = nil


      #################
      ## OAuth - step 2
      #################
      # Request token from twitter and give user
      @twitter_authentication_url = request_token.authorize_url        
      
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end

    redirect_to @twitter_authentication_url
    return

  end
  
  
  # Client programs authorization to Twitter account is directed to here.
  # Returns: 201 - Success
  #          409 - Failed
  def twitter_client_callback

      #################
      ## OAuth - step 3
      #################
    
      begin

        puts "Twitter OAUTH step 3"
        
        if params["oauth_token"] && params["oauth_token"] != nil && 
          params["oauth_verifier"] && params["oauth_verifier"] != nil
          
          if not params[:username]
            raise Exception.new("Error: Could not find user in session!")
          end
          
          # Make sure the user has 'twitter_auth' process begun
          @user = User.find_by_username(params[:username])
          
          si = ServiceInformation.find_by_user_id_and_service_type(@user.id, 'twitter_auth')
          
          if si == nil || si.auth_token == nil || si.auth_secret == nil
            raise Exception.new("Error: could not find twitter_auth information!")
          end 
          
          client = TwitterOAuth::Client.new(
                                    :consumer_key => @@twitter_consumer_key,
                                    :consumer_secret => @@twitter_consumer_secret )
          
          access_token =  client.authorize(
                            si.auth_token, 
                            si.auth_secret,
                            :oauth_verifier => params[:oauth_verifier] )
          
          
                     
          
          # Put the twitter token and secret to database
          twitter_si = ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, 
                                                                                     :service_type => 'twitter',
                                                                                     :auth_secret => access_token.secret,
                                                                                     :auth_token => access_token.token)
          
          # Remove the temporary 'twitter_auth' from database, since it is no longer needed
          puts "user id: #{@user.id}"
          sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "twitter_auth"])
          sis.each do |si|
            si.delete
          end
                      
      end #if
      
    rescue Exception => e      
      putsE(e)
      render :text => "There was an error in step 3 of the Twitter OAuth", :status => 409
      return  
    end
    
    render :text => "Authentication succesful, you can now return to the program you came here from!", :status => 201
    return
 end




  def twitterPublish
    
    begin
    
      if not @auth_user
        puts "Authentication failed!"
        render :text => "Unauthorized - 401", :status => 401
        return
      end

      # Authenticated user
      @user = @auth_user
      
      if not params[:message] || params[:message] == ""
        raise Execption.new("Could not find message!")
      end
      
      message = params[:message]
         
      # Checks if user already has auth token for twitter
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "twitter"])
       
      # If user already had auth token
      if not si
        raise Exception.new("Could not find service information!")
      end

      client = TwitterOAuth::Client.new( :consumer_key    => @@twitter_consumer_key,
                                         :consumer_secret => @@twitter_consumer_secret,
                                         :token           => si.auth_token,
                                         :secret          => si.auth_secret )
                                         
      if client.authorized? == false                                        
        raise Exception.new("Could not connect to twitter!")
      end                                  
      
      # Publish the message in twitter
      client.update(message) 
        
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
    
    render :text => "Published in Twitter: #{message}", :status => 200
  end


  def twitterDeleteToken
    puts "Remove Twitter token"
    
    if not session[:username]
      render :text => "User not logged in!", :status => 401
      return
    else
      @user = User.find_by_username(session[:username]) 
    end
    
    begin
      sis = ServiceInformation.find(:all, :conditions => ["user_id = ? and service_type = ? ", @user.id, "twitter"])
      sis.each do |si|
        si.delete
      end
    rescue Exception => e
      putsE(e)
      render :text => "Failed to delete token!", :status => 500
      return
    end
    render :text => "Token deleted successfully!", :status => 200
    return
  end


  def twitterConnected
  
    begin

      if not @auth_user
        puts "Authentication failed!"
        render :text => "Unauthorized - 401", :status => 401
        return
      end

      # Authenticated user
      @user = @auth_user
         
      # Checks if user already has auth token for twitter
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "twitter"])
       
      # If user already had auth token
      if not si
        render :text => "No access token for Twitter was found!", :status => 401
        return
      end

      client = TwitterOAuth::Client.new( :consumer_key    => @@twitter_consumer_key,
                                         :consumer_secret => @@twitter_consumer_secret,
                                         :token           => si.auth_token,
                                         :secret          => si.auth_secret )
                                         
      if client.authorized? == false                                        
        raise Exception.new("Access token might be old!")
      end                                  
        
    rescue Exception => e
      putsE(e)
      render :text => "Error, couldn't find access token to Twitter': #{e.to_s}", :status => 409
      return
    end
    
    render :text => "Twitter access token is valid.", :status => 200
    return
  
  end

  
      ################################
      ####### TWITTER ENDS ###########
      ################################


  
end
