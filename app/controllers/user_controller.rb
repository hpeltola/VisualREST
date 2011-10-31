class UserController < ApplicationController
  
  # Protection from cross site request forgery
  protect_from_forgery :except => [ :addGroup, :deleteGroup, :register, :deleteUser, :deleteDevices,
                                    :deleteDevice, :deleteDeviceFiles, :deleteAllUserFiles, 
                                    :createContext, :modifyContext, :modifyUser, :addNode, :deleteNode,
                                    :contextSettings, :emailSettings, :virtualContainerSettings, 
                                    :importContentFromFlickr, :getThumbnail, :getUser]
  
  # These methods need authentication:
  before_filter :authenticate, :only => [:settings, :addGroup, :deleteGroup, :deleteUser, 
                                         :deleteDevices, :deleteDevice, :deleteDeviceFiles,
                                         :deleteAllUserFiles, :editUsersGroups, :saveUsersGroups,

                                         :deviceSettings, :modifyUser, :manageEmails,
                                         :addObserver, :emailSettings, :contextSettings, 
                                         :virtualContainerSettings, :importContentFromFlickr, 
                                         :importContentFromFB ]

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
    
    user = User.find_by_username("nikkis")
    context = Context.find_by_id(10)
    
    XmppHelper::pushToUserNode_invited_or_uninvaited_from_context(user, context, true)
    
    render :text => "Message was given for worker to send to context node!", :status => 202
    return
    
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
    puts
    puts "filename löyty"
      
        @virtualContainerManager = VirtualContainerManager.new(user, device.dev_name)
      puts "manageri luotu"
        @virtualContainerManager.addFile(@filename, params[:upload]['datafile'].read)
          puts "tiedosto lisätty"
        @virtualContainerManager.commit
      puts "kaikki ohi"
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
        #format.yaml { render :text => YAML.dump(@yaml_results), :layout=>false }
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
  # - join your email address to it
  #   * Get all old email attachments
  #   * every 10 minutes, check for new attachments
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

 # Manage users email accounts
 # Used for fetching mail and saving attachments to to server
 def importContentFromFlickr
   puts "import content from flickr"
   if not session[:username]
     render :text => "Error, failed to authenticate user!", :status => 401
     return
   end

  @user = User.find_by_username(session[:username])

  if @user == nil
    render :text => "Error, failed to find user!", :status => 401
    return
  end
  
  if params[:delete_flickr_token]
    flickr_data = ServiceInformation.find_by_user_id_and_service_type(@user.id, "flickr")
    if flickr_data != nil
      flickr_data.destroy
    end
  end
  
  @flickr_data = ServiceInformation.find_by_user_id_and_service_type(@user.id, "flickr")

  # If user doesn't have a flickr token saved, it needs to be saved
  if @flickr_data == nil

    perms = "read"
    api_sig = Digest::MD5.hexdigest(@@flickr_secret+'api_key'+@@flickr_api_key+'perms'+perms)
  
    @flickr_url = "http://flickr.com/services/auth/?api_key=#{@@flickr_api_key}&perms=#{perms}&api_sig=#{api_sig}"

  else
    
    # Gets photos from Flickr, if getPhotosFromFlickr parameter was given
    @amountOfPhotosFromFlickr = 0
    @gettingPhotosFromFlickr = getPhotosFromFlickr
      
    if @gettingPhotosFromFlickr == true
      @gettingToContainer = params[:container_name] 
    end
    
    # List of users containers
    @virtualUserDevices = Device.find_all_by_user_id_and_dev_type(@user.id, "virtual_container")
    
    
    
  end

  render :update do |page|
    page["import_content_from_flickr"].replace_html :partial => 'import_content_from_flickr'
  end
 end
  
  # This function gets users photos from Flickr. The photos are either public or private photos of user.
  def getPhotosFromFlickr
    if params[:getPhotosFromFlickr] && params[:getPhotosFromFlickr] == "true" && 
      params[:container_name] && params[:privacy_setting]
      
      container = Device.find_by_user_id_and_dev_type_and_dev_name(@user.id, "virtual_container", params[:container_name])
      if container == nil
        return false
      end
      
      if params[:privacy_setting] == "public"
        privacy_setting = 1
      elsif params[:privacy_setting] == "private"
        privacy_setting = 5
      else 
        return false
      end

      
      # Make photo search in Flickr for User's photos
      method = "flickr.photos.search"
      
      calculate_this = "#{@@flickr_secret}api_key#{@@flickr_api_key}" +
                       "auth_token#{@flickr_data.s_token}" +
                       "method#{method}" +
                       "privacy_filter#{privacy_setting}" +
                       "user_id#{@flickr_data.s_id}"

      api_sig =  Digest::MD5.hexdigest(calculate_this)
      
      
      flickr_url = "http://api.flickr.com"
      flickr_params = "/services/rest/?api_sig=#{api_sig}&" +
                                     "api_key=#{@@flickr_api_key}&" +
                                     "auth_token=#{@flickr_data.s_token}&" +
                                     "method=#{method}&" +
                                     "privacy_filter=#{privacy_setting}&" +
                                     "user_id=#{@flickr_data.s_id}"
      #puts flickr_params
      begin
        url = URI.parse(flickr_url)
        res = Net::HTTP.start(url.host, url.port) {|http|
          http.get(flickr_params)
        }
        xml = res.body
        if xml == nil
          return false
        end
        
        doc = XML::Document.string(xml) 
        #puts "XML:   #{xml}"
  
        @amountOfPhotosFromFlickr = doc.find_first('//photos')['total']
        puts
        puts "Number of files to download from Flickr to virtual container: #{@amountOfPhotosFromFlickr}"
        puts 
        if @amountOfPhotosFromFlickr == nil || @amountOfPhotosFromFlickr == "0"
          return false
        end  

        ##### Start new thread for retrieving files from flickr #####
        Thread.new do
          downloadUserPhotosFromFlickr(doc, container)              
        end
        ##### END #####
  
        # Set the time when files were fetched
        if privacy_setting == 1
          @flickr_data.update_attribute(:extra_1, Time.now)
        elsif privacy_setting == 5
          @flickr_data.update_attribute(:extra_2, Time.now)
        end
        return true
      rescue => e
        putsE(e)
      end       
    end
    
    return false
  end
    
  # This function is run in a thread. It downloads files from Flickr and saves them to VisualREST in a virtual container
  def downloadUserPhotosFromFlickr(doc, container)

    begin   
      @virtualContainerManager = VirtualContainerManager.new(@user, container.dev_name)
          
      nodes = doc.find('//photos/photo')
                      
      nodes.each do |node|
              
        if node['farm'] != nil && node['server'] != nil && node['id'] != nil && 
          node['secret'] != nil && node['title'] != nil
              
          # Build url 
          photo_url = "http://farm"+node['farm']+".static.flickr.com"
          photo_params = "/"+node['server']+"/"+node['id']+"_"+node['secret']+".jpg"
                
          purl = URI.parse(photo_url)
                
          # Get the photo
          photo = Net::HTTP.start(purl.host, purl.port) {|http|
            http.get(photo_params)
          }
                
          filename = '/' + node['title'] + ".jpg"
                
          @virtualContainerManager.addFile(filename, photo.body)
          puts "File " + filename + " created."
                                
          ### Get photo info
          getPhotoInfoFromFlickr(node['id'], node['secret'], container, filename)              
          
        end
              
      end    
            
    rescue => e
      puts e
    end      
    @virtualContainerManager.commit
  end
  
  # This function is used for getting photo info from Flickr. The info will be saved as metadata for the file in VisualREST
  def getPhotoInfoFromFlickr(photo_id, photo_secret, container, filename)
    begin
      
      method = "flickr.photos.getInfo"      
         
      flickr_url = "http://api.flickr.com"
      flickr_params = "/services/rest/?api_key=#{@@flickr_api_key}&" +
                                      "method=#{method}&" +
                                      "photo_id=#{photo_id}&" +
                                      "secret=#{photo_secret}"
            

      url = URI.parse(flickr_url)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.get(flickr_params)
      }

      xml = res.body
      
      if xml == nil
        #next
      end

      doc = XML::Document.string(xml) 
              
      # Description
      description = doc.find_first('//photo/description').content
      if description != nil && description.strip != ""
        @virtualContainerManager.addMetadata(filename, "description", description.strip)
        puts "   Description: #{description}"
      end
              
      # Datetime taken
      taken = doc.find_first('//photo/dates')['taken']
      if taken != nil && taken.strip != ""
        @virtualContainerManager.addMetadata(filename, "taken", taken.strip)
        puts "   Picture taken: #{taken}"
      end
              
      # Tags
      tags = doc.find('//photo/tags/tag')
      tags.each do |tag| 
        @virtualContainerManager.addMetadata(filename, "tag", tag['raw'])
        puts "   Tag: #{tag['raw']}"
      end
              
      # Url
      url_photo = doc.find_first('//photo/urls/url').content
      if url_photo != nil && url_photo.strip != ""
        @virtualContainerManager.addMetadata(filename, "url", url_photo.strip)
        puts "   Photo url: #{url_photo}"
      end
      
      # Origin
      @virtualContainerManager.addMetadata(filename, "origin", "flickr")
      
      puts
      puts "FETCHING METADATA FOR FILE IS NOW DONE."
      puts "\n"
    rescue => e
      puts e
    end
    
    return  
  end
  
  
  # Flickr sends frob here. Now we need to get token using frob.
  # Save the token user table.
  def flickrAuthentication
    if not session[:username]
      render :text => "Error, failed to authenticate user!", :status => 401
      return
    end
    
    @user = User.find_by_username(session[:username])

    if @user == nil
      render :text => "Error, failed to find user!", :status => 401
      return
    end


    @receivedToken = false
          
    if params[:frob] && params[:frob] != ""

      frob = params[:frob]
      method = "flickr.auth.getToken"
      
      api_sig =  Digest::MD5.hexdigest("#{@@flickr_secret}api_key#{@@flickr_api_key}frob#{frob}method#{method}")

      flickr_url = "http://api.flickr.com"
      flickr_params = "/services/rest?api_key=#{@@flickr_api_key}&api_sig=#{api_sig}&method=#{method}&frob=#{frob}"
      
      begin
        url = URI.parse(flickr_url)
        res = Net::HTTP.start(url.host, url.port) {|http|
          http.get(flickr_params)
        }
        xml = res.body
        doc = XML::Document.string(xml) 
        
        token = doc.find_first('//auth/token').content
        nsid = doc.find_first('//auth/user')['nsid']
        flickr_username = doc.find_first('//auth/user')['username']
        
        if token != nil && nsid != nil && flickr_username != nil
          puts "Token: #{token}"
          puts "NSID: #{nsid}"
          puts "Username: #{flickr_username}"
          @receivedToken = true
          flickr_data = ServiceInformation.find_or_create_by_user_id_and_service_type(@user.id, "flickr")
          flickr_data.update_attribute(:s_token, token)
          flickr_data.update_attribute(:s_id, nsid)
          flickr_data.update_attribute(:s_username, flickr_username)
        end
      rescue => e
        putsE(e)
      end  
      
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
  
  
  def test
   # puts "set_#{params[:file_devfile_id]}"
    
   # puts "voi jee: " + params[:file_devfile_id]
    
    modifyObserversForFile
    
    puts "Renderointi"
    render :update do |page|
      page["set_#{params[:file_devfile_id]}"].replace_html :partial => 'pala'#, :locals => {:status => stat, :image => params[:image]} 
    end
    
    puts "the end"
    
    
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
          client_info = {:id => @user.xmpp_jid+'@visualrest.cs.tut.fi', :psword => @user.xmpp_pw,
                         :host => @user.xmpp_host, :port => 5222, :plain_id => @user.xmpp_jid,
                         :node_service => "pubsub.#{@user.xmpp_host}"}
          @node_names = XmppHelper::getMyNodes(client_info, true)
        else
          render :text => "User no logged in!", :status => 300
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
  


  # REST, uses PUT:

  
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
=begin
  def addGroup_orig
    
    @title = "Add new group"
    # Tests if method is used from web site or if used from client.
    if (request.put? and params[:group]) or (request.put? and params[:groupname])
      
      user = User.find_by_username(params[:username])
      if params[:groupname]
        @group = Group.create(:name => params[:groupname], :user_id => user.id)
      else
        @group = Group.create( params[:group] )
      end
      
      # Tries to save the new group
      if @group.save
            # Adds user to group
            #  Usersingroup.create(:user_id => @user.id, :group_id => @group.id, :created_at => DateTime.now, :updated_at => DateTime.now)
        flash[:notice] = "Group #{@group.name} created!"
        if params[:i_am_client]
          # Used through REST
          render :text => "Group #{@group.name} created - 201", :status => 201
        else
          # Used from site
          redirect_to :action => "settings"
        end
      else
        # If saving did not succeed:
        if params[:i_am_client]
          render :text => "Group #{@group.name} already exists - 409", :status => 409
          return
        else
          flash[:notice] = "Group #{@group.name} already exists!"
          redirect_to :action => "addGroup"
        end
      end
      
    end
  end
=end
  
  def addGroup
    user = User.find_by_username(params[:username])
    if params[:groupname] and request.put? or params[:groupname] and request.post?
      @group = Group.find_or_create_by_name_and_user_id(:name => params[:groupname], :user_id => user.id)
      # Tries to save the new group
      if @group
        if params[:i_am_client]
          # Used through REST
          render :text => "Group #{@group.name} created - 201", :status => 201
        else
          #@groups = Group.find(:all, :conditions => ["user_id = ? ", user.id])
          #render :update do |page|
          #  page["group_settings"].replace_html :partial => 'usergroup'
          #end
          return
        end
      else
        # If saving did not succeed:
        if params[:i_am_client]
          render :text => "Error in creating new group: #{@group.name} - 409", :status => 409
          return
        end
      end
    end
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
    puts "foo"
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
    
    # Deletes users fromthe group 
    puts "Deleting users from the group..."
    @group.users.each do |u|
      authgroup = u.groups.find(:first, :conditions => ["group_id = ?", @group.id])
      if authgroup
        u.groups.delete(authgroup)
      end
    end
    
    puts "Deleting group #{@group.name} from db.."
    # Deletes the actual group
    @group.delete
=begin
    # If used from another method, returns true if group was deleted successfully.
    if fromAnotherMethod
      puts "Whole group deleted.."
      return true
    else
      # Used through REST:
      puts "Whole group deleted.."
      render :text => "OK - 200", :status => 200
      return
    end
=end
    if params[:i_am_client]
      # Used through REST:
      puts "Whole group deleted.."
      render :text => "OK - 200", :status => 200
      return
    else
      #@groups = Group.find(:all, :conditions => ["user_id = ? ", @user.id])
      #render :update do |page|
      #  page["group_settings"].replace_html :partial => 'usergroup'
      #end
      render :text => "OK - 200", :status => 200
      return
    end
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
    ActiveRecord::Base.connection.execute("begin")
    params[:groups].each do |user_id, user_group_settings|
      user_group_settings.each do |group_id, checked|
        if checked == "1" and (users_and_groups[user_id.to_i] == nil or not users_and_groups[user_id.to_i].include?(group_id.to_i))
          # user isn't previously a member of the group, so he needs to be added to the group
          sql = "INSERT INTO usersingroups(user_id, group_id, created_at, updated_at) values(#{user_id}, #{group_id}, '#{now}', '#{now}');"
          ActiveRecord::Base.connection.execute(sql)
          
          modified_groups_for_pubsub_node << group_id
          
        elsif checked == "0" and (users_and_groups[user_id.to_i] != nil and users_and_groups[user_id.to_i].include?(group_id.to_i))
          # user is previously a member of the group, so he needs to be removed from the group
          sql = "DELETE FROM usersingroups WHERE user_id = #{user_id} AND group_id = #{group_id};"
          ActiveRecord::Base.connection.execute(sql)
          
          modified_groups_for_pubsub_node << group_id
          
        end    
      end
    end
    ActiveRecord::Base.connection.execute("commit")
    
    
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
        Usersingroup.create(:user_id => @edit_user.id, :group_id => group.id, :created_at => DateTime.now, :updated_at => DateTime.now)
        
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
      puts "fuuru"
      
      sql = "SELECT contexts.* 
             FROM contexts, context_group_permissions, groups 
             WHERE groups.id = '" + group_id.to_s + "' AND 
                   groups.id = context_group_permissions.group_id AND 
                   context_group_permissions.context_id = contexts.id LIMIT 1;"
      
      context = Context.find_by_sql(sql).first
      
      if context
    puts "jekke"      
          begin
            puts "Sends notification to node!"
            XmppHelper::publishToContextGeneralNode(context, "Context Members Modified!", "context-modified")
            puts "Notification sent!"
          rescue Exception => ee
            putsE(ee)
          end
      else
        puts "noppe"      
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
    puts "bar"
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
  #     FACEBOOK STUFF
  #
  ##########################################################################################
  
  
  
  
  #
  #   Gets authentication token from facebook. Goes in two phases: 1. Oauth,  2. Gets token and saves it
  #
  #
  def fb_login
   
   puts "foo1"
   
    @og_host = @@og_host
    @fb_app_id = @@fb_app_id
    @fb_app_secret = @@fb_app_secret
    @my_url = "#{@@http_host}/fb_login/"
    #@my_url = "http://130.230.144.235:8080/fb_login/"
    
    if not session[:username]
      puts "fb_login"
      redirect_to :action => "login", :controller => "user"
      return
    else
      @user = User.find_by_username(session[:username]) 
    end
    
    
    # Vaihe 1.
    if not params["code"] or params["code"].empty?
      puts "redirecting to oauth.."
            
      puts "myuri: #{@my_url}"
      @dialog_url = "https://www.facebook.com/dialog/oauth?client_id=" + @fb_app_id + "&redirect_uri=" + @my_url + "&scope=email,read_stream,user_photos"
      puts "d uri: #{@dialog_url}"   
      render "fb_redirect_to_authentication.html"
      return
          
        
    # Vaihe 2.
    else
      puts "Oauth completed.. Get token.."
      
      code = params["code"]  
      token_path = "/oauth/access_token?client_id=" + @fb_app_id + "&redirect_uri=" + @my_url + "&client_secret=" + @fb_app_secret + "&code=" + code
      res = HttpRequest.new(:get, token_path).send(@og_host)
      
      # If token was received
      if res and res.code == "200"
        puts "vastatus:"
        @access_token = res.body
        puts "token: " + @access_token
        token = @access_token.sub('access_token=', '')
        
        # Gets user id
        res = HttpRequest.new(:get, "/me?#{@access_token}").send(@og_host)
        user_info = JSON.parse(res.body)
        #puts user_info.to_s
        #puts "Nimi: #{user_info["name"]}"
        puts "ID: #{user_info["id"]}"
        s_id = user_info["id"]
        
        if s_id and token
          ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, :service_type => "facebook", :s_id => s_id, :s_token => token)
        else
          render :text => "Error could not fetch token!", :status => 409
          return
        end

      else
        puts "Could not get fb auth token.."
      end
      
      redirect_to "/user/#{session[:username]}/settings"
      #render :text => "Token was fetched and saved!", :status => 200
      return
    end
 end  
  
  
  #
  #   Deletes the access token of facebook
  #
  def fbDeleteToken
    
    puts "poispoispois...tytydyydydyydy!"
    
    if not session[:username]
      puts "fb_login"
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
  
  
  def fbSettings
    
    @og_host = @@og_host
    if not session[:username]
      puts "fbSettings"
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

    @photo_albums = {}
    if @fb_auth_token
      # Photo albums
      begin
        #timeout(10.seconds) do
          path = "/me/albums?access_token=#{@fb_auth_token.s_token}"
          res = HttpRequest.new(:get, path).send(@og_host)
          
          photo_albums = JSON.parse(res.body)
          photo_albums = photo_albums["data"]
          puts photo_albums.to_s
          photo_albums.each do |album|
            puts "album name: " + album["name"].to_s + "  id  " + album["id"]
            @photo_albums.merge!({album["name"] => album["id"]})
          end

        #end #timeout
      rescue Exception => e
        putsE(e)
      end

    end
    
    render :update do |page|
      page["import_content_from_fb"].replace_html :partial => 'import_content_from_fb'
    end
    return 
  end
  

  def fbImportFromAlbums
    puts "fbImportFromAlbums"
    # Tähän viä dropdown johon haetann??
    @og_host = @@og_host
    if not session[:username]
      redirect_to :action => "login", :controller => "user"
      return
    else
      @user = User.find_by_username(session[:username]) 
    end
    si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "facebook"])
    if not si
      render :text => "No access token for facebook was found!", :status => 401
      return
    end
    @fb_auth_token = "access_token=#{si.s_token}"
    puts "token: #{@fb_auth_token}"
    
    if params["container_name"]
      container_name = params["container_name"]
    else
      container_name = "facebook_container"
    end
    
    virtualContainerManager = VirtualContainerManager.new(@user, container_name)
    
    params['checked_albums'].each do |row|
      if row.second == "1"
        puts "albumi: " + row.first + " oli chekattu!"
        
        begin
        
          i = 0
          
          # Album information
          res = HttpRequest.new(:get, "/#{row.first}?#{@fb_auth_token}").send(@og_host)
          album_info = JSON.parse(res.body)
          
          # Photos of the album
          res = HttpRequest.new(:get, "/#{row.first}/photos?#{@fb_auth_token}").send(@og_host)
          if res and res.code == "200" and res.body != ""
            
            album_photos = JSON.parse(res.body)
            album_photos = album_photos["data"]
               
            album_photos.each do |photo|
              puts "..photo desc: " + photo["name"].to_s
              puts "..photo url: " + photo["source"].to_s
              photo_url = URI.parse(photo["source"].to_s)
             
              photo_essence = nil
              photo_essence = HttpRequest.new(:get, photo_url.path).send("http://#{photo_url.host}").body
        
              pic_name = '/' + album_info["name"] + "_#{i.to_s}.jpg"
              pic_name = pic_name.sub(' ', '_')
              
              virtualContainerManager.addFile(pic_name, photo_essence)
              
              virtualContainerManager.addMetadata(pic_name, "origin", "facebook")
              
              if photo["name"]
                virtualContainerManager.addMetadata(pic_name, "description", photo["name"].to_s)
              end
              
              if photo["source"]
                virtualContainerManager.addMetadata(pic_name, "url", photo["source"].to_s)
              end
              
              
              i += 1
            end
          end
        rescue Exception => ex
          putsE(ex)
        end
      else
        puts "albumi: " + row.first + " EI OLLU chekattu!"
      end
    end
    
    virtualContainerManager.commit
    d = virtualContainerManager.getDeviceObject
    
    redirect_to "/user/#{@user.username}/device/#{d.dev_name}/files"
    #render :text => "jepa", :status => 200
    return
  end



##################################################################################
#
#    Dropbox stuff
#
##################################################################################

  
  def dropboxSettings
    
    begin
      
      @dropbox_host = @@dropbox_host
      @db_app_id = @@db_app_id
      @db_app_secret = @@db_app_secret
      
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
    
    
    
    
      # Ensures that user has virtual_container called: facebook_container
      VirtualContainerManager.new(@user, "dropbox_container")
  
      # User's virtual containers
      @v_containers = @user.devices.find(:all, :conditions => ["dev_type = ?", "virtual_container"])
      
      # Chacks if user already has auth token for facebook
      si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ? ", @user.id, "dropbox"])
      
      
      # If user already had auth token, finds dropbox root folders
      @db_dirs = []
      if si
        puts "oli"
        @db_auth_token = si
        
        i = 0
        begin
          filepath = "/metadata/dropbox/"
          path = DropboxHelper.new(@user).dbCalculateSignaturedPath(@@dropbox_host, filepath,si,true)
          res = HttpRequest.new(:get, path).send(@dropbox_host)
          puts res.code.to_s
          puts res.body.to_s
   
          if res.code.to_s == "200"
            info = JSON.parse(res.body)
            if info and info["contents"]
              info["contents"].each do |cont|
                if cont["is_dir"]
                  
                  puts "Dir: #{cont["path"]}"
                  puts "   modified: #{cont["modified"]}"
                  
                  @db_dirs << cont["path"]
                end
              end
            end
          else
            puts "Other dropbox error!"
          end
        
        rescue Exception => e
          puts "1"
          putsE(e)
          i += 1
          puts "Err: #{i.to_s}"
          sleep(0.5)
          retry if i < 5
          puts "2"
        end

      else
        @db_auth_token = nil
      end

    rescue Exception => e
      putsE(e)
    end
    
    
    render :update do |page|
      page["dropbox_settings"].replace_html :partial => 'dropbox_settings'
    end
    return 
  end
  
  
  def getDropboxToken
    
    begin
      @user = User.find_by_username(session[:username])
      email = params["uname"] #"hermannihiiri.tty@gmail.com"
      password = params["passw"] #"hermannittyhiiri"
      
      path = "/0/token?email=#{email}&password=#{password}&oauth_consumer_key=#{@@db_app_id}"
      res = HttpRequest.new(:get, path).send(@@dropbox_host)
      puts res.body.to_s
      
      if res.code.to_s != "200" or res.code.to_s != "304" 
        info = JSON.parse(res.body)
        if info["token"] and info["secret"]
          ServiceInformation.find_or_create_by_user_id_and_service_type(:user_id => @user.id, :service_type => "dropbox", :s_id => info["secret"], :s_token => info["token"])
        else
          render :text => "Error could not fetch token!", :status => 409
          return
        end
      end
      
      
    rescue Exception => e
      putsE(e)
      render :text => "Error in fetching access token!", :status => 409
      return
    end
    
    render :text => "Access token was successfully fetched!", :status => 200
    return
  end
  
  
  
  def dbCreateDirPoller
    
    begin
      @dir2poll = params["checked_dir"]
      puts "Dir to Poll: #{@dir2poll}"
      
      
      @dropbox_host = @@dropbox_host
      @db_app_id = @@db_app_id
      @db_app_secret = @@db_app_secret
      @my_url = "#{@@http_host}/fb_login/"
      
      if not session[:username]
        puts "db_login"
        redirect_to :action => "login", :controller => "user"
        return
      else
        @user = User.find_by_username(session[:username]) 
      end
      
      # Ensures that user has virtual_container called: facebook_container
      vM = VirtualContainerManager.new(@user, params["container_name"])
      
      dev_id = vM.getDeviceObject.id
      
      begin
        # Clears all the old content
        dh = DeleteHelper.new(dev_id)
        dh.removeContent
        puts "Old content deleted!"
      rescue Exception => p
        putsE(p)
      end
      
      # Chacks if user already has auth token for facebook
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
      puts "fb_login"
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
  def dbDeleteToken
    
    puts "poispoispois...tytydyydydyydy!"
    
    if not session[:username]
      puts "fb_login"
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
  
  
  
  
end
