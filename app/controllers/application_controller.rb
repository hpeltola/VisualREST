# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

# Solves the server port from commandline parametres
p = false
ARGV.each do |a|
    if a.to_s == '-p'
    p = true
    end
    if p
    $port = a
    end
end

class ApplicationController < ActionController::Base
    
    @host = @@http_host

    helper :all # include all helpers, all the time
    #  protect_from_forgery # See ActionController::RequestForgeryProtection for details
    #  protect_from_forgery :secret => 'secretpass'

    # Picks a unique cookie name to distinguish our session data from others'
    #session :session_key => '_rails_space_session_id'
    # Method is used to send xmpp messages to clients.
    #
    # Parameters: whole xmpp name, and the message.
    # Uses worker, which is background process.
=begin
    def sendXmppMessage(receiver, message)
        if receiver == ""
        return
        end
        MiddleMan.worker(:xmpp_worker).async_sendMessage(:arg => {:receiver=>receiver,:message=>message})
    end

    def createXmppNode(node_path, client_info)
        if node_path == ""
          return
        end
        #args = {:node_name => node_name}
        MiddleMan.worker(:xmpp_worker).async_createNode(:arg => {:node_path => node_path, :client_info => @@node_client_info})
        return node_path, @@node_client_info[:node_service]
    end

    def publishToXmppNode(node_path, message, client_info, element_name = nil)
        if node_path == "" or message == "" or client_info == nil
          return
        end
        #args = {:node_name => node_name, :message => message, :element_name => element_name}
        MiddleMan.worker(:xmpp_worker).async_publishToNode(:arg => {:node_path => node_path, :message => message, :element_name => element_name, :client_info => client_info})
    end
=end
    
    # Authentication for the user. Works with client interface and web-ui
    # Client interface works by calculating a hash with the password on the client and server side
    # Web-ui works with login and cookies (session) and also username in uri is needed!
    # Note that the user is authenticated in relation to the password, but not in relation to the requested resource
    # This you need to check in specific controllers for example in protect method
    #
    # Usage: This method is used by those methods that are mentioned at the begining of each controller (before_filter)
    def authenticate
        @auth_user = nil
#puts "1"
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
            password = User.find_by_username(params["username"]).password
            @auth_user = User.find_by_username(params["username"])
            # Hash that is calculated from the request
            hash = Digest::SHA1.hexdigest(params["auth_timestamp"] + password + request.path)

            if params["i_am_client"] == "xmpp2rest"
                hash = Digest::SHA1.hexdigest(params["auth_timestamp"] + "nota" + request.path)
            end

            # If hash didn't match to the one given in request params
            if params["auth_hash"] != hash
                puts "unknown user, authentication failed (c3)"
                render :text => "Unauthorized - 401", :status => 401
                return
            end

        # web-ui
        else

        # the requested resource did not include username
            if not params["username"]
                puts "unknown user authentication failed (w1)"
                flash[:notice] = "Unknown user"
                redirect_to :action => "login", :controller => "user"
            return
            end

            # no session (user not logged in)
            if not session[:username]
                puts "unknown user, authentication failed (w2)"
                flash[:notice] = "You must login first"
                redirect_to :action => "login", :controller => "user"
            return
            end

            # pretending to be someone else than the username in request
            if params["username"] != session[:username]
                puts "unknown user, authentication failed (w3)"
                flash[:notice] = "Unauthorized access"
                redirect_to :action => "login", :controller => "user"
                return
            end
            @auth_user = User.find_by_username(params["username"])
        end
        puts "user " + params["username"] + " authentication ok"
    end

    # Authenticates client.
    # Used for queries that don't require authentication, but can have authentication.
    # Returns username of authorized user.
    # If not authorized, returns nil.
    #
    # Params needed: params[:i_am_client]     - using some client, not web-ui
    #                params[:auth_username]   - username that will be authenticated
    #                params[:auth_timestamp]  - used for calculating hash
    #                params[:auth_hash]       - hash calculated by client
    def authenticateClient
        puts "Authenticating client started!"
        # Check client
        if params["i_am_client"]
#puts "1"
            # the requested resource did not include username
            if !params["auth_username"]
              return nil
            end
#puts "2"
            # authentication tokens missing
            if !params["auth_timestamp"] or !params["auth_hash"]
              return nil
            end
#puts "3"
            # calculate hash and compare with client hash
            user = User.find_by_username(params["auth_username"])

            if user == nil
              return nil
            end

            password = user.password
#puts "4"
            # Hash that is calculated from the request
#puts "auth_string" + params["auth_timestamp"] + password + request.path
            hash = Digest::SHA1.hexdigest(params["auth_timestamp"] + password + request.path)
#puts "5"
            # if params["i_am_client"] == "xmpp2rest"
            #   hash = Digest::SHA1.hexdigest(params[:auth_timestamp] + "nota" + request.path)
            # end
#puts "6"
            # If hash didn't match to the one given in request params
            if params["auth_hash"] != hash
puts "#{hash}  vs. #{params["auth_hash"]}"
#puts "7"
              return nil
            end

            else
              return nil
            end

        puts "Client authentication with user #{params["auth_username"]} OK"
        return params["auth_username"]
    end
    
  # Returns: true, if user is authorized to context
  # If context is public, no need to sign in.
  # @user has the user-object who is signed in. If nil, not signed in
  def authorizedToContext(context_hash)
    
    # Find the context
    context = Context.find_by_context_hash(context_hash)
    if context == nil
      return false
    end
  
    # If context is public, return true
    if context.private == false
      return true
    end
    
    # If user not signed in, return false
    if @user == nil
      return false
    end    
         
    # If user is the owner of context
    if @user.id == context.user_id
      return true
    end
       
       
    # Is user in a group that is authorized for the context
                
    # Groups that user is in
    uigroups = Usersingroup.find_all_by_user_id(@user.id)
    if uigroups == nil
      return false
    end
          
    # Is group autohorized for the context
    uigroups.each do |uigroup|
           
      group = ContextGroupPermission.find_by_group_id_and_context_id(uigroup.group_id, context.id)
            
      # If group is authorized for the context, return true
      if group != nil
        return true
      end
    end
      
    return false
  end
  
    
  # Return true, if @user is authorized to devfile
  def authorizedToDevfile(fileID)
    
    devfile = Devfile.find_by_id(fileID)
    
    # Find the devfile
    if devfile == nil
      return false
    end
    
    # Is the devfile private
    if devfile.privatefile == false
      return true
    end
    
    if @user == nil
      return false
    end
    
    ## If user is the owner, he is authorized
    if devfile.device.user.id == @user.id
      return true
    end
    
    ## Is user in a group that is authorized for the devfile
                
    # Groups that user is in
    uigroups = Usersingroup.find_all_by_user_id(@user.id)
    if uigroups == nil
      return false
    end
    
    device = devfile.device
    
          
    # Is group autohorized for the devfile
    uigroups.each do |uigroup|
           
      group = DevfileAuthGroup.find_by_group_id_and_devfile_id(uigroup.group_id, devfile.id)
            
      # If group is authorized for the devfile, return true
      if group != nil
        return true
      end
      
      # Is the device of the devfile authorized for the group
      devAuth = DeviceAuthGroup.find_by_device_id_and_group_id(device.id, uigroup.group_id)
      if devAuth != nil
        return true
      end
      
      
    end
      
    return false
    
  end
    
  

    # Creates one string from given params for sql-queries
    def searchtermForSql(term, sql_column_name)
        if term !~ /[^\w\.\s\-\_\+]/
            # split given values into an array and add some chars needed in the sql query
            term.gsub!("+", " ")
            values = term.split(" ").join("%' '%")
            values = ("'%" + values + "%'").split(" ")
            if term == "" or term =~ /^\s$/
                values = ["'%'"]
            end

            #combine the searchstring and do the search
            searchstring = sql_column_name + " LIKE " + values.first
            values.each_index do |i|
                next if i == 0
                searchstring += " OR " + sql_column_name + " LIKE " + values[i]
            end
        return searchstring
        end
    end

    # Get file's path and filename
    #
    # Parameters: filepath must be found in the URL.
    #
    # Method splits the url's filepath-parameter to path and filename and stores them
    # to @path and @filename.
    #
    def getPathAndFilename #:doc:
        if params[:filepath]
            if params[:filepath].size == 1 # no path, just filename
                @path = "/"
                @filename = params[:filepath][0]
            elsif params[:filepath].size > 1
                pathparts = params[:filepath][0..-2]
                @path = "/" + pathparts.join("/") + "/"
                @filename = params[:filepath][-1]
            end
        end
    end

    #  Add new MetadataType
    #
    #  Returns: Http code 200 - Metadatatype already exists
    #           Http code 201 - MetadataType added
    #           Http code 404 - Failed to add metadataType
    #
    #  Params: value_type: "string"/"float"/"date/datetime". "string" is default.
    #
    #  Example with curl: 'curl -X PUT http://localhost:8080/metadatatype/new_type -d "value_type=date"'
    #
    def addMetadataType
        begin
        # Name of the metadatatype to be added
            name = params[:metadatatypename].to_s.strip.downcase
            value_type = params[:value_type].to_s.strip.downcase

            if value_type == ""
                value_type = "string"
            elsif value_type != "string" && value_type != "float" && value_type != "date" && value_type != "datetime"
                render :text => "Invalid value_type", :status => 404
            return
            end

            # Check that type doesn't exist already
            # @@existing_metadata_types listed in the beginning of file
            if MetadataType.find_by_name(name) or @@existing_metadata_types.include?(name)
                render :text => "Metadatatype already exists", :status => 200
            return
            end

            # Create new type
            @newtype = MetadataType.create(:name => name, :value_type => value_type)
            render :text => "Metadatatype created", :status => 201
            return
        rescue => e
            puts "Error in adding metadatatype: #{e.to_s}".background(:red)
            render :text => "Conflict", :status => 409
        return
        end
    end

    #  Change MetadataType
    #  - Changes metadatatype name. Value_type Can't be changed.
    #
    #  Returns: Http code 200 - MetadataType changed
    #           Http code 404 - Failed to change metadataType
    #
    #  Example with curl: 'curl -X POST http://localhost:8080/metadatatype/oldtype -d "new_metadata_type=newtype"'
    #
    def changeMetadataType
        begin
            old_type = params[:metadatatypename].to_s.strip.downcase
            new_type = params[:new_metadata_type].to_s.strip.downcase
            puts "old_t: " + old_type
            puts "new_t: " + new_type

            if old_type == ""
                render :text => "Type of metadata not given", :status => 404
            return
            end

            if new_type == ""
                render :text => "Type of new metadata not given", :status => 404
            return
            end

            # Find old metadata type
            @metadatatype = MetadataType.find_by_name(old_type)

            # If old metadata type was not found
            if @metadatatype == nil
                render :text => "Old metadata type not found", :status => 404
            return
            end

            # Check that new type doesn't exist already
            # @@existing_metadata_types listed in the beginning of file
            if MetadataType.find_by_name(new_type) or @@existing_metadata_types.include?(new_type)
                render :text => "Type of new metadata already exists", :status => 404
            return
            end

            # Change metadata type name
            @metadatatype.update_attribute(:name, new_type)
            render :text => "Metadata type changed", :status => 200
            return

        rescue => e
            puts "Error in changing metadatatype: #{e.to_s}".background(:red)
            render :text => "Conflict", :status => 409
        return
        end
    end

    #  Delete MetadataType and all metadata of that type
    #
    #  Returns: Http code 200 - MetadataType and all metadata of that type deleted
    #           Http code 404 - Failed to delete MetadataType
    #
    #  Example with curl: 'curl -X DELETE http://localhost:8080/metadatatype/tyyppi'
    #
    def deleteMetadataType
        begin
            type = params[:metadatatypename].to_s.strip.downcase
            puts "Type to be removed: " + type

            if type == ""
                render :text => "Type of metadata not given", :status => 404
            return
            end

            # Search metadatatype
            metadatatype = MetadataType.find_by_name(type)

            # Check that type was found
            if metadatatype == nil
                render :test => "Metadatatype not found", :status => 404
            end

            # Delete all metadata of that type
            Metadata.destroy_all(["metadata_type_id = ? ", metadatatype.id])

            # Delete metadata type
            metadatatype.destroy
            render :text => "Metadatatype and metadata of that type deleted", :status => 200
            return

        rescue => e
            puts "Error in deleting metadatatype: #{e.to_s}".background(:red)
            render :text => "Conflict", :status => 409
        return
        end
    end

    # Parses username, devicename, filepath, filename and version number from given vR-uri
    #
    # returns username, devicename, filepath, filename
    # raises exception if all the parts are not found
    def parseFileInfoFromURI(uri)

        path = URI.parse(uri).path

        username = nil
        devname = nil
        filepath = "/"
        filename = nil
        version = "latest"

        parts = path.split(/\//, 7)

        parts.each_with_index do |p, i|

            if p == 'user' and parts.count > i+1
            username = parts[i+1]
            elsif p == 'device' and parts.count > i+1
            devname = parts[i+1]
            elsif p == 'files' and parts.count > i+1
                file = parts[i+1]

                filepath = file.split(/[^\/]+$/)[0]
                if not filepath
                    filepath = "/"
                end

                filename = file[/[^\/]+$/].split(/\?/)[0]
                params = file.split(/\?/, 2)

                if params.count > 1

                    params = params[1].split(/&/)

                    params.each do |p|
                        if p.split(/=/)[0] == 'version'
                            version = p.split(/=/)[1]
                        end
                    end

                    if not version
                        version = :latest
                    end
                end
            end
        end
        if not (username and devname and filepath and filename)
            raise Exception.new("Not all the parts found from uri")
        else

            if filepath[0,1] != '/'
                filepath = '/' + filepath
            end

        return username, devname, filepath, filename, version
        end
    end

    def getDevfileFromURI(uri)
        username, devicename, filepath, filename, version = parseFileInfoFromURI(params[:file_uri])
        file_user = User.find_by_username(username)
        file_device = file_user.devices ? file_user.devices.find_by_dev_name(devicename) : nil
        devfile = file_device ? file_device.devfiles.find(:first, :conditions => ["name = ? and path = ?", filename, filepath]) : nil
        if not devfile
            puts "Devfile of the URI: #{uri} was NOT found!"
            raise Exception.new("Devfile of the URI: #{uri} was NOT found!")
        else
          return devfile
        end
    end


    def putsE(e)
        puts "Error: #{e.to_s}"
        puts "  -- line: #{e.backtrace[0].to_s}"
    end

    # Method sets the @device variable and updates last seen variable in database
    #
    # parameters: username and devicename must be given in parameters
    #
    def identifyDevice(markOnline = true) #:doc:

        if not params[:i_am_client]
          return false
        end

        # Tries to find device
        @device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
        return false if @device == nil

        if markOnline
        # update database
        @device.update_attribute(:last_seen, DateTime.now)
        end

        @port = nil
        if params[:port]
            @port = params[:port]
        end

        # Ensures that session has data (so that the session exists) and
        # that the session_id can be set in a cookie.
        #session[:ensure_session] = 0

        # Sets cookie for session_id.
        #cookies[:ses_id] = { :value => request.session_options[:id], :expires => 1.year.from_now }
        #render :text => "1", :code => 200

        return true
    end


    def http_get(domain,path,params)
        return Net::HTTP.get(domain, "#{path}?".concat(params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&'))) if not params.nil?
        return Net::HTTP.get(domain, path)
    end





    # Creates and scales icon from given data and saves it as given name
    def createIcon(data, icon_name, icon_path)

        begin
            icon_data = data

            # Scaling the icon
            img = Image.from_blob(icon_data).first
            icon = scale(img)

            # create dir if it does not exist
            if not (File.exists?(icon_path) && File.directory?(icon_path))
            FileUtils.mkdir_p(icon_path)
            end

            # create the file path
            full_path = File.join(icon_path, icon_name)

            icon.write("png:"+ full_path)

        rescue Exception => e
            putsE(e)
        return false
        end

        return true
    end

    def scale(i)

        i.change_geometry!('128x128') { |cols, rows, img|
          img.resize!(cols, rows)
        }

        return i
    end

=begin
    def getHost
      if request.ssl?
        @@host = "https://#{request.host}"
      else
        @@host = "http://#{request.host}"
      end
      if request.port != nil and request.port != 80
        @@host += ":#{request.port}"
      end
      @host = @@host
    end
=end

end






class BlobRepresentation
  # getter and setter
  attr_reader :device_id, :username, 
              :dev_name, :name, 
              :thumbnail_name, :description, 
              :version, :path, :filetype, 
              :size, :rank, :blob_hash, 
              :longitude, :latitude, 
              :last_seen, :uploaded,
              :updated_at, :devfile_id,
              :metadatas
  
  def initialize(blob_id)
    
    @blob = Blob.find(:first, :conditions => ['id = ?', blob_id])
    if not @blob
      raise Exception.new("Blob not found")
    end
    
    # blob
    @thumbnail_name = @blob.thumbnail_name
    @size = @blob.size
    @updated_at = @blob.updated_at
    @version = @blob.version
    @blob_hash = @blob.blob_hash
    @latitude = @blob.latitude
    @longitude = @blob.longitude
    @uploaded = @blob.uploaded.to_s
#puts "1"
    # devfile
    @devfile = @blob.devfile
    @devfile_id = @devfile.id
    @name = @devfile.name
    @path = @devfile.path
    @description = @devfile.description
    @filetype = @devfile.filetype
    @rank = @devfile.rank
#puts "2"
    # device
    @device = @devfile.device
    @device_id = @device.id
    @dev_name = @device.dev_name
    @last_seen = @device.last_seen.to_s 
    
#puts "3"
    # user
    @user = @device.user
    @username = @user.username
#puts "4"

    metadatas = {}
    mds = Metadata.find(:all, :conditions => ['devfile_id = ?', @devfile.id])
    if mds != nil
      mds.each do |md|
        mdvalue = metadatas[md.metadata_type.name.to_s]
        if mdvalue == nil
          mdvalue = md.value.to_s
        else
          mdvalue = mdvalue + ', ' + md.value.to_s
        end
        metadatas.merge!({md.metadata_type.name.to_s => mdvalue})
      end
    end    
    @metadatas = metadatas
  end
  
  def get_uri(format = :html)
    
    if format == :atom
      return "#{@@http_host}/user/#{@username}/device/#{@dev_name}/metadatas#{@path}#{@name}?format=atom"
    else
      return "#{@@http_host}/user/#{@username}/device/#{@dev_name}/metadatas#{@path}#{@name}"
    end

  end
  
  
  def to_yaml(host="")
    
    file_status = "not cached"
    if @uploaded == "1" or @uploaded == "true" then file_status = "cached" end
    device_status = "offline"
    if @device.last_seen > 2.minutes.ago then device_status = "online" end
        res = {"#{@path}#{name}" => {
      "thumbnail" => "#{@@http_host}/thumbnails/#{@device_id}/#{@blob_hash}.png",
      "essence_uri" => "#{@@http_host}/user/#{@username}/device/#{@dev_name}/files#{@path}#{@name}",
      "description" => @description,
      "file_user" => @username,
      "file_version" => @version,
      "filename" => @name,
      "filepath" => @path,
      "filetype" => @filetype,
      "filesize" => @size,
      "rank_value" => @rank,
      "file_device" => @dev_name,
      "file_status" => file_status,
      "device_status" => device_status,
      "file_versionlist_url" => "#{@@http_host}/user/#{@username}/device/#{@dev_name}/fileversions#{@path}#{@name}?format=atom",
      "updated" => @updated_at,
      "version_hash" => @blob_hash,
      "metadatas" => @metadatas,
      "device_id" => @device_id.to_s
    }}
  end
  
  
  def to_yaml1
    
    res = {"#{@path}#{name}" => {
      "name" => @name,
      "path" => @path,
      "filedate" => @updated_at,
      "blob_hash" => @blob_hash,
      "size" => @size,
      "metadatas" => @metadatas
    }}

    return res
  end
  
  
 
  
end







