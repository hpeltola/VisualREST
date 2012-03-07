require 'cgi'
require 'cgi/session'



# Class that controls certain device. Device can be registered, put online and its 
# filelist can be updated by this class.
class DeviceController < ApplicationController
  layout nil
  
  # Protection from cross site request forgery
  # These methods are also used from client and they cannot use authencity token:
  protect_from_forgery :except => [:updateFilelist, :online, :register, 
                                   :deleteDevice, :updateFileList]
  
  # These methods needs authentication:
  before_filter :authenticate, :only =>[:online, :updateFilelist]



  def preRegister
    puts "preUpload STARTED!!!"
    if params["access-control-allow-origin"] && params["access-control-allow-origin"] == "true"
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'PUT'  
      #headers['Access-Control-Request-Method'] = '*'  
    end
    render :text => "preUpload OK", :status => 200
  end

  
  # Registers new device to the system.
  #
  # parameters: username and devicename must be given in uri /user/{username}/device/{devicename}/. 
  # password and dev_type must be given in http request parameters.
  # 
  # If parameter dev_type has value "virtual_container", a virtual device will be created on the server.
  #
  # Renders text: 0 and returns http code 417 if all parameters was not given. 
  # If user, given in parameters, was not found renders text and retruns http code 401.
  # If any errors occours during registration, renders text and returns http code 409.
  # If device with same parameters already exists, renders text: Already registered, http code 200.
  # If registration was successful, renders id_diggest as a text, and returns http code 201.
  #
  # Usage (through REST): 
  #   Send PUT to /user/{username}/device/{devicename}/ with parameters: password and dev_type.
  def register
    
    if params["access-control-allow-origin"] && params["access-control-allow-origin"] == "true"
      headers['Access-Control-Allow-Origin'] = '*'
      #headers['Access-Control-Request-Method'] = '*'  
    end
    
    # check for missing parameters
    if check_params == false
      #      @message = "0"
      render :text => "0", :status => 417 # Expectation Failed. The server cannot meet the requirements of the Expect request-header field.
      return
    end
    
    user = User.find(:first, :conditions => ["username = :username and password = :password", params])
    if user == nil
      # if user cannot be identified
      #      @message = "Invalid username or password"
      render :text => "Unauthorized - 401", :status => 401
      return
    end
    
    # check if user already has a device with the same name registered
    device = user.devices.find(:first, :conditions => ["dev_name = :devicename", params])
    if device == nil
      
      
      # If devicename = virtula_container, creates a virtual device on the server
      begin
        if params[:dev_type] == "virtual_container"
          @xmppName = ""
          @xmppPassword = ""
                user.devices.create(:dev_name => params[:devicename],
                            :dev_type => params[:dev_type],
                            :last_seen => DateTime.now,
                            :direct_access => false,
                            :xmppname => @xmppName,
                            :xmpppasswd => @xmppPassword)
                            
          render :text => "Registeration OK, created new virtual container", :status => 201
          return        
        end
      
      rescue => e
        puts e
        render :text => "0", :status => 409
        return
      end
        
        
      
      # register new device
      
      begin
        # Register new device to xmpp server
        @xmppName = user.username + "_" + params[:devicename] + "@" + @@xmpp_host
        @xmppPassword = params[:password]
        # add to database
        user.devices.create(:dev_name => params[:devicename],
                            :dev_type => params[:dev_type],
                            :last_seen => DateTime.now,
                            :direct_access => false,
                            :xmppname => @xmppName,
                            :xmpppasswd => @xmppPassword)
      rescue => e
        puts e
        #        @message = "0"
        render :text => "0", :status => 409
        return
      end
Jabber::debug = true
      # The usual procedure
      cl = Jabber::Client.new(Jabber::JID.new(@xmppName))
      
      puts "Xmppname: " + @xmppName
      puts "Xmpp server port: " + @@xmpp_port.to_s()
      
      i = 0
      begin
        puts "Connecting"
        cl.connect(@@xmpp_host, @@xmpp_port)
        # Registration of the new user account
        puts "Registering..."
        cl.register(@xmppPassword)
        puts "Successful"
        cl.close
        
      rescue => exception
        
          puts "Ex: " + exception
          puts "Error in xmpp registration:"
          puts "Xmpp username: " + @xmppName
          puts "Xmpp server: " + @@xmpp_host
          puts "Xmpp server port: " + @@xmpp_port.to_s()
          
        if i < 5
          i += 1
          sleep(1)
          retry
        else
          
          cl.close
          # Deletes device from db, if errors in creating xmpp account
          device = user.devices.find_by_dev_name(params[:devicename])
          puts "Deletes from db device: " + params[:devicename]
          puts "id: " + device.id.to_s
          device.delete
          #        @message = "0"
          render :text => "0", :status => 409
          return
        end
      end
      
      # New thread for resolving device's files.
      Thread.new do
        
        # Tries to find the device which just was created.
        @device = user.devices.find_by_dev_name(params[:devicename])
        
        # Client http address:
        @client_address = "http://" + request.remote_ip
        puts @client_address
        if params[:port] != nil
          @client_address = @client_address + ":" + params[:port].to_s
        end
        
        # Gets metadate of the device's files.
        getMetadata
      
      end
      render :text => "Registeration OK", :status => 201
    else
      # if already registered
      puts "Already registerd!"
      render :text => "Already registered", :status => 200
    end
  end

  
  
  
  
  # Marks certain device online.
  # Renders text: Unauthorized and http code 401, if device can not be authorized.
  #
  # Usage:
  #   Send POST to /user/{username}/device/{devicename}/online with (optional) location parameters
  def online
    if not identifyDevice
      render :text => "Unauthorized - 401", :status => 401
      return
    end
    
    errors = false
    code = false
    if params[:status] != nil
      
      @status = YAML.load(params[:status])
      @status.each do |key, value|
        
        if key == 'uploading_file'
          errors, code = beginUpload(value.to_s)
          
        elsif key.to_s == 'device_location'
          params_location = YAML.load(value)
          puts "la"
          puts "lat: " + params_location['latitude'].to_s
          puts "lo"
          puts "lon: " + params_location['longitude'].to_s
          
          latest_location = @device.device_locations.find_by_id(@device.latest_location_id)
        #  puts "last lat: " + latest_location.latitude.to_s + " last long: " +  latest_location.longitude.to_s
        #  puts " newydev lat: " + params_location['latitude'].to_S + "  new long: " +  params_location['longitude'].to_s
          if latest_location != nil and latest_location.latitude == params_location['latitude'] and latest_location.longitude == params_location['longitude']

              latest_location.update_attribute(:updated_at, DateTime.now)
          elsif params_location['latitude'] > 84.5 or params_location['latitude'] < -84.5
            
            puts "kakaa!"
            errors = "Error in location's latitude"
            code = 409
          
          else
              l = @device.device_locations.create(:device_id => @device.id, :latitude => params_location['latitude'], :longitude => params_location['longitude'], :created_at => DateTime.now, :updated_at => DateTime.now)
              @device.update_attribute(:latest_location_id, l.id)
          end
          
          
        end
      end
    end
    
    if errors
      render :text => errors, :status => code
      return
    end
    render :text => "Device marked online", :status => 201
  end
  
  def beginUpload(fullpath)
    # Creates new fileupload
    errors = nil
    code = nil
    blob_hash = @status['uploading_file_hash'].to_s
    puts "blob_hash: " + blob_hash
    if blob_hash == nil
      errors = "Error in creating fileupload! (Blob_hash not found)"
      code = 300
      return errors, code
#      render :text => "error. no file hash given", :status => 300
#      return
    end
    file = nil
    if @device != nil
      if fullpath
        if fullpath.size > 1
          
          name_start = fullpath.rindex('/')
          if name_start == nil
            errors = true
          end
          @filename = fullpath[(name_start + 1)..-1]
          @path = fullpath[0..name_start]
          if @path.empty?
            @path = "/"
          end
        end
      end
      if @filename == nil or @path == nil
        errors = "Error in creating fileupload! (Check path and filename)"
        code = 300
      end

      file = @device.devfiles.find(:first, :conditions => ["name = ? and path = ?", @filename, @path])
    end
    if file != nil
      blob = file.blobs.find(:first, :conditions => ["blob_hash = ?", blob_hash])
      if blob != nil
        fup = Fileupload.find_by_blob_id(blob.id)
        if fup != nil
          # previous upload (???)
          fup.destroy  
        end
        puts "creating fileupload"
        Fileupload.create(:begin_time => DateTime.now, :blob_id => blob.id)
        puts "File upload begin on file: " + file.name + " (" + file.id.to_s + "/" + blob_hash +")"
      else
        errors = "Error in creating fileupload! (db)"
        code = 300
      end
    else
      errors = "Error in creating fileupload! (File not found. Ensure fullpath)"
      code = 300
    end
  

    return errors, code

  end
  
  
  
  

  

  
  
  
  # Gives date-time when device was last seen online.
  #
  # Renders text: Device not found and http code 404, if device can not be found from db.
  # Renders text: date-time of when device was last seen and http code 200, if device was found.
  #
  # Usage:
  #   Send GET to /user/{username}/device/{devicename}/online
  def getLastSeen
    
    # Tries to find device from db.
    device = User.find_by_name(params[:username]).devices.find_by_dev_name(params[:devicename])
    if device == nil
      render :text => "Device not found - 404", :status => 404
      return
    end
    
    
    render :text => device.last_seen, :status => 200
    
  end
  
  






  # Updates filelist of a device. Sends xmpp-message to device when filelist
  # is fully and successfully parsed.
  #
  # parameters: auth_timestamp, auth_hash, i_am_client must be added in request parameters. auth_hash is calculated from the request 
  # username - in uri 
  # devicename - in uri
  # commit_hash - client's git's commit-hash
  # prev_commit_hash - if client has previous commits, the hash of the one before this commit must be given
  # contains - contains the changed and created files
  # commit_location (opt) - the location of the device when it is making the commit. (optional)
  #
  # Renders: Code 202 when filelist successfully received
  # Renders: Code 401 if error
  #
  # Usage:
  #   Send PUT to /user/{username}/device/{devicename}/files with parameters: client_id.
  def updateFilelist
    
    
    begin
      puts "contains: #{params["contains"].to_s}"
      testi = YAML.load(params["contains"])
    rescue Exception => eee
      eee.to_s
      render :text => "ERROR: Malformed metadata contains list. The format is: 
      contains: --- 
      /1.jpg: \n  name: 1.jpg \n  filedate: 12:21:53 2010-10-29 \n  size: 20662 \n  filetype: image/jpeg \n  path: / \n  blob_hash: cf9912eddafaa932e9e172ae79eec38b168435c5 \n  status: created", :status => 400
      return
    end
    
    
    begin
      @device = User.find_by_username(params[:username]).devices.find_by_dev_name(params[:devicename])
      if @device == nil
        render :text => "ERROR: Device can't be identified", :status => 401
        return
      end
      
      commit = nil
      puts "contains: " + params["contains"].to_s
      puts "commit_hash" + params["commit_hash"].to_s
      puts "prev_commit_hash" + params["preve_commit_hash"].to_s
      # check for correct commit-hashes
      if not params["commit_hash"].to_s.strip =~ /^\w{40}$/        
        render :text => "ERROR: Unidentified Commit-hash", :status => 412
        return
      else
        commit = @device.commits.find_by_commit_hash(params["commit_hash"])
        if commit != nil
          # if commit has blobs, don't parse given filelist
          if commit.blobs.size > 0
            puts "Commit already exists, sending parse successful.."
            XmppHelper::sendXmppMessage(@device.xmppname, "parse successful " + commit.commit_hash)
            # check if thumbnails are missing
            checkForThumbs(commit)
            render :text => "Commit already in database", :status => 202
            return
          end
        end
      end

      if params["prev_commit_hash"] =~ /^\w{40}$/ and @device.commit_id != nil
        @prev_commit = Commit.find_by_id(@device.commit_id)
        if @prev_commit != nil and @prev_commit.commit_hash != params["prev_commit_hash"]
          render :text => "ERROR: Commit not accepted", :status => 412
          return
        end
      else
        if not (params["prev_commit_hash"] == nil and @device.commit_id == nil)
          render :text => "ERROR: Unidentified prev_commit_hash: #{params["prev_commit_hash"]}", :status => 412
          return
        end
      end

      if commit == nil
        puts "creates new commit"
        commit = @device.commits.find_or_create_by_previous_commit_id_and_commit_hash(:previous_commit_id => @device.commit_id,
                                        :commit_hash => params["commit_hash"])
        puts "updates newly created commit to device"
        # Updates created to commit to device
        @device.update_attribute(:commit_id, commit.id)
      end
      @device.update_attribute(:last_seen, DateTime.now)
      
    rescue Exception => ex
      putsE(ex)
    end
    
    # Thread that goes through filelist and parses it, when finished sends xmpp message to inform client.
    Thread.new do
      begin
        @changed_files = YAML.load(params["contains"])
        # Checks that which files are completely new and which ones already exists (has devfile)
        @changed_files.each do |key, df|
          old_df = Devfile.find_by_name_and_path_and_device_id(df['name'], df['path'], @device.id)
          # If the dev_file already exists
          if old_df
            puts "Already exists: #{key}"
            df.merge!({:dev_file_id => old_df.id.to_s})
            @changed_files[key] = df
            puts "Ensure: " + @changed_files[key].to_s
          else
            puts "Completely new: #{key}"
          end
        end
        
         
        
        
        if params[:commit_location]
          @commit_location = YAML.load(params[:commit_location])
          lat = @commit_location['latitude'].to_f
          lon = @commit_location['longitude'].to_f
          if lat == nil or lon == nil
            @commit_location = {'latitude' => 0, 'longitude' => 0}
          end
        else
          @commit_location = {'latitude' => 0, 'longitude' => 0}
        end
        
        @notify_these_observers = {}
        
        commit_devfiles = []
        
        @changed_files.each do |key, f|
          
          devfile = nil
          
          if f[:dev_file_id] or f['status'] == "updated"
            
            devfile = updateDevfile(f, commit)
            
          elsif f['status'] == "created"
            
            devfile = createDevfile(f, commit)
            
          elsif f['status'] == "deleted"
            
         #   deleteDevfile(f, commit)
            
          else
            puts "Unknown status. Status can be: deleted, updated or created"
          end
          
          
          #
          #  Notifications for nodes:
          #
          if devfile
            # Checks if devfile had any observers, and nofies them about updates
            checkForObservers(devfile)
            
            # Checks if devfile matches to any context, and notifies matching contexts
            # => This includes cases were devfile has been added to a context as well as cases where
            # => parameters of a context matches to parameters of the devfile
            commit_devfiles << devfile
            
          end
          
          
        end
        
        Thread.new do
          ContextController::notifyObservers(commit_devfiles)
        end
        
        
        # add all unchanged files from previous commit to this new one
        if @prev_commit != nil
          addUnchangedFilesToCommit(@prev_commit, commit, @changed_files)
        end

      rescue => e
        linenumb = e.backtrace[0].to_s
        
        puts "-- PARSE ERROR on device: " + @device.dev_name + " (" + @device.id.to_s + ")" + " line: #{linenumb}"
        puts "  --  line: #{linenumb}"
        
        XmppHelper::sendXmppMessage(@device.xmppname, "parse error " + commit.commit_hash + " Error: " + e.to_s)
        @error = true
        
        
        
        # tämä täytyy tehdä uusiksi! Eli homma täytyy tehdä niin että kokonaan uuden tiedoston ja uuden version lisääminen
        # tapahtuu samalla tavoin. Ennen kuin koko hommaa edes aloitetaan tutkitaan, että ollaanko luomassa kokonaan uutta
        # device.devfiles.find_by_name_and_path.. Jos tulos on nil tiedetään että luodaan uutta, muuten päivitetään vanhaa..
        #
        # Rollbackissa voidaan helposti poistaa myös devfile, mikäli oltiin luotu kokonaan uusi tiedosto
        
        
        # Cancelling the new commit by deleting it, and setting device's commit to the old one
        cancelCommit(commit)
        
      end
      if not @error
        XmppHelper::sendXmppMessage(@device.xmppname, "parse successful " + commit.commit_hash)
        sleep(1)
        XmppHelper::sendXmppMessage(@device.xmppname, "thumbs " + commit.commit_hash)
      end
    end
    
    # Response code that tells that parsing is started.
    render :text => "Filelist parsing started..", :status => 202    
  end
  
  
  
  #
  #   Checkse if devfile has any user added observers and sends notification to those nodes
  #
  def checkForObservers(devfile)
    begin
      path = "/user/" + params[:username] + "/device/" + params[:devicename] + "/files" + devfile.path + devfile.name
      devfile.file_observers.each do |fo|
        begin
          if fo
            XmppHelper::notificationToNode(fo, devfile, "Content updated!")
          end
        rescue Exception => ex
          putsE(ex)
        end    
      end      
    rescue Exception => e
      puts "Error in cheking checking devfile for observers!"
      puts "  -- line: #{e.backtrace[0].to_s}"
    end
  end
  
  
  
  
  
  
  
=begin
  # Sends xmpp-notification for the clients that are registered as observers for the changed files
  #
  def notifyClientsFromUpdates
puts "notifying clients:"
    if @notify_of_these and not @notify_of_these.empty?
       @notify_of_these.each do |xmpp_name, file_uri|
puts "..xmppname: #{xmpp_name}"
         XmppHelper::sendXmppMessage(xmpp_name, "File updated: #{file_uri}")
puts "..notifed"
       end
puts "..done"
    end
  end
=end

  def cancelCommit(commit)
  
    puts "Cancelling the new commit by deleting it, and setting device's commit to the old one, deleting also the blobs, blobs_in_commits and devfiles concenring about this commit"
          
    begin
      
      puts "Deleting blobs and blobs_in_commits.."
      BlobsInCommit.find(:all, :conditions => ["commit_id = ?", commit.id.to_s]).each do |b_in_c|
        b = Blob.find_by_id(b_in_c.blob_id)
        BlobsInCommit.delete_all(["commit_id = ? AND blob_id = ?", b_in_c.commit_id.to_s, b_in_c.blob_id.to_s])
        
        if not b
          puts "..ei ollu blobii"
        else
          puts "..blobi oli juu"
        end
                
        if b
          b.delete
        end
      end
    
      puts "done!"
      
      
      puts "Deleting the devfiles that are created in this commit!"
      @changed_files.each do |key, df|
        if not df[:dev_file_id]
          puts "  Deleting devfile: #{key}"
          new_df = Devfile.find_by_name_and_path_and_device_id(df['name'], df['path'], @device.id)
          new_df.delete if new_df
          puts "  done!"
        end
      end
      
      
      puts"done!"
      
      
      puts "Setting the old commit_id to devfile.."
      old_commit_id = @prev_commit != nil ? @prev_commit.id : nil
      @device.update_attribute(:commit_id, old_commit_id)
      
      
      puts "done!"
      
      commit_hash = commit.commit_hash
      
      puts "deleting the actual commit.."
      commit.delete
      
      puts "done!"
      
      
      puts "Cancelled the commit: " + params["commit_hash"]
    
      XmppHelper::sendXmppMessage(@device.xmppname, "cancelled commit: " + commit_hash)
    
    rescue Exception => exception
      puts "Error in cancelling the commit: #{exception.to_s}"
      puts "  -- line #{exception.backtrace[0].to_s}"
      commit.delete
    end


  end


  

  
  
  
  
  
  
  private
    
  
  # Method is used to get metadata of device's files.
  #
  # parameters: @device is get from method identifyDevice.
  #
  # Returns false if wasn't able to send xmpp message or if filelist parsing fails.
  # Returns true if metadata was updated successfully.
  def getMetadata #:doc:
    
    if @device == nil
      return false
    end
    
    puts "SENDING XMPP *****"
    # try to reach device through XMPP
    XmppHelper::sendXmppMessage(@device.xmppname, "list")
    @device.update_attribute(:xmpp_request_sent, DateTime.now)
    
  end
  
  

  
  
 

  # Updates file's metadata to db
  #
  # parameters: f - filehash
  #             commit - the commit the file belongs to
  #
  # @device has to be set.
  def updateDevfile(f, commit) #:doc:
    
    dev_file = nil
    
    begin
      # Checks if there is any changes in files.
      f_filedate = DateTime.strptime(f['filedate'], "%T %F")
      f_filedate = f_filedate.strftime('%F %T').to_s        
      
      now = DateTime.now.strftime('%F %T')
puts "name: #{f['name']}"
puts "path: #{f['path']}"
      puts "Finding devfile.."
      dev_file = @device.devfiles.find(:first, :conditions => ["name = ? and path = ?", f['name'], f['path']])
      if dev_file != nil
        puts "devfile found: " + dev_file.id.to_s
      else
        puts "Devfile not found"
        raise Exception.new("Devfile not found. Can not update it!")
      end
      
      
      blob = dev_file.blobs.find_by_blob_hash_and_devfile_id(f['blob_hash'], dev_file.id)
      if blob != nil
        puts "Blob already exists!"
        puts "Blob: " +  blob.id.to_s
        return
      else
        puts "Blob was not found!"
      end
      
      # Finds the blob that is newest one
      previous_blob_id = nil
      current_blob = dev_file.blobs.find_by_id(dev_file.blob_id)
      if current_blob != nil
        previous_blob_id = current_blob.id.to_s
        puts "Current blob: " +  current_blob.id.to_s
        
      end
      
      # If the blob, didn't exist yet, creates it. Ensures that blob will have version number.
      if blob == nil #or current_blob == nil
        version = 0
        if current_blob != nil
          version = current_blob.version + 1
        end
        
        puts "Creates new blob, verion num: " +  version.to_s
        sql = "insert into blobs(blob_hash, created_at, updated_at, size, filedate, uploaded, version, devfile_id, predecessor_id, latitude, longitude) values('#{f['blob_hash']}', '#{now}', '#{now}', '#{f['size']}', '#{f_filedate}', '0', '#{version}', '#{dev_file.id}', '#{previous_blob_id}', '#{@commit_location['latitude']}', '#{@commit_location['longitude']}');"
        ActiveRecord::Base.connection.execute(sql)
      end
      
      puts "Finding the newly created blob.."
      blob = dev_file.blobs.find_by_blob_hash(f['blob_hash'])
      puts " found blob: " + blob.id.to_s
      
      current_blob.update_attribute(:follower_id, blob.id)
      
      puts "Updating devfile"
      # Updates changes in devfile (current blob)
      sql = "update devfiles set filetype = '#{f['filetype']}', latitude = '#{f['latitude']}', longitude = '#{f['longitude']}', blob_id = '#{blob.id.to_s}', updated_at = '#{now}'  where name = '#{f['name']}' and path = '#{f['path']}' and device_id = #{@device.id};"
      puts " SQL: " + sql.background(:red)
      ActiveRecord::Base.connection.execute(sql)
      
      BlobsInCommit.find_or_create_by_blob_id_and_commit_id(blob.id, commit.id)
      
      
      #checkForObservers(dev_file)
      
    rescue => e
      puts "Errors in updating file" + e
      raise e
    end
    
    puts "devfile updated!"
    return dev_file
  end



  # Creates metadata of a new file to db
  #
  # parameters: f - file
  #             commit - the commit the file belongs to
  #
  # @device has to be set.
  def createDevfile(f, commit) #:doc:
    
    dev_file = nil
    blob = nil
    b_in_c = nil
    
    # If file already exists, raises an error but nothing needs to be deleted (except the commit is cancelled)
    begin    
      dev_file = Devfile.find_by_name_and_path_and_device_id(f['name'], f['path'], @device.id)
      if dev_file != nil
        puts "Devfile: #{f['path'] + f['name']} already exits, cannot create, use update instead"
        raise ArgumentError.new("Devfile already exits for this device, cannot use CREATE -method, use UPDATE instead to add new version")
      end
    rescue Exception => e
      puts e.to_s
      puts e.backtrace[0].to_s
      raise e
    end
puts "name: #{f['name']}"
puts "path: #{f['path']}"
    
    # If something goes wrong, raises an error, and deletes the data created
    begin
      
      puts "Creating new dev_file, blob etc.."
      
    
      f_filedate = DateTime.strptime(f['filedate'], "%T %F")
      f_filedate = f_filedate.strftime('%F %T').to_s
      
      now = DateTime.now
      
      # get or create devfile
      dev_file = Devfile.find_or_create_by_name_and_path_and_device_id(f['name'], f['path'], @device.id)
      if dev_file.created_at >= now
        sql = "update devfiles set filetype='#{f['filetype']}', path='#{f['path']}', privatefile=0 where id=#{dev_file.id}" 
        ActiveRecord::Base.connection.execute(sql)
      end
      
      # get or create blob
      blob = Blob.find_or_create_by_blob_hash_and_devfile_id(f['blob_hash'], dev_file.id)
      if blob.created_at >= now # if just created
        # Version number
        version = 0
        predecessor_blob_id = "NULL"
        follower_blob_id = "NULL"
        if dev_file.blob_id != nil
          predecessor_blob_id = dev_file.blobs.find_by_id(dev_file.blob_id) ? dev_file.blobs.find_by_follower_id(dev_file.blob_id).id.to_s : "NULL"
          follower_blob_id = dev_file.blobs.find_by_predecessor_id(blob.id) ? dev_file.blobs.find_by_predecessor_id(blob.id).id.to_s : "NULL"
          version = dev_file.blobs.find_by_id(dev_file.blob_id).version + 1 
        end
        
puts "predecessor_id=#{predecessor_blob_id.to_s},"
puts "follower_id=#{follower_blob_id.to_s},"
puts "size=#{f['size'].to_s}," 
puts "filedate='#{f_filedate.to_s}'," 
puts "version=#{version.to_s}," 
puts "uploaded='0',"  
puts "latitude=#{@commit_location['latitude'].to_s}, " 
puts "longitude=#{@commit_location['longitude'].to_s} "        
        
        sql = "update blobs set predecessor_id=#{predecessor_blob_id.to_s}, follower_id=#{follower_blob_id.to_s}, size=#{f['size'].to_s}, filedate='#{f_filedate.to_s}', version=#{version.to_s}, uploaded='0', latitude=#{@commit_location['latitude'].to_s}, longitude=#{@commit_location['longitude'].to_s} where id=#{blob.id};"
puts "sql: " + sql
        
        ActiveRecord::Base.connection.execute(sql)
      end
      
      # Creates association between blob and commit
      b_in_c = BlobsInCommit.find_or_create_by_blob_id_and_commit_id(blob.id, commit.id)
      
      # update blob_id to devfile
      if dev_file.blob_id != blob.id
        sql = "update devfiles set blob_id=#{blob.id} where id=#{dev_file.id};"
        ActiveRecord::Base.connection.execute(sql)
      end
      
      
      #checkForObservers(dev_file)
      
      # If parent_blob_hash is given, tries to find the parent, and creates new branch form the parent
      if f['file_origin']        
        createBranch(f['file_origin'], blob)
      end

    rescue Exception => e
      puts "        -- Error in createDevfile: " + e
      puts "          -- line: #{e.backtrace[0].to_s}"
      
      puts "Deleting created data.."
      
      # If dev_file was created now, deletes it
      dev_file.delete if dev_file
      puts "Deleted created dev_file!" if dev_file
      
      if blob      
        if b_in_c
          BlobsInCommit.delete_all(["commit_id = ? AND blob_id = ?", b_in_c.commit_id.to_s, blob.blob_id.to_s])
          puts "Deleted created blobs_in_commits!" if b_in_c
        end
        blob.delete 
        puts "Deleted created blob!"
      end
      
      # Throws forward the exception..
      raise e
    end
    puts "File created"
    return dev_file
  end





  # add blobs from prev_commit to commit ignoring blobs in changed_files
  #
  # parameters: prev_commit - The previous commit
  #             commit - new commit
  #             changed_files - list of files to ignore
  #
  def addUnchangedFilesToCommit(prev_commit, commit, changed_files) #:doc:
#    sql = "select devfiles.path, devfiles.name, devfiles.blob_id from devfiles, blobs, blobs_in_commits where blobs.devfile_id=devfiles.id and blobs_in_commits.blob_id=blobs.id and blobs_in_commits.commit_id=#{prev_commit.id};"
#    devfiles_of_prev_commit = ActiveRecord::Base.connection.execute(sql)
#
    devfiles_of_prev_commit = Devfile.find_by_sql("select devfiles.path, devfiles.name, devfiles.blob_id from devfiles, blobs, blobs_in_commits where blobs.devfile_id=devfiles.id and blobs_in_commits.blob_id=blobs.id and blobs_in_commits.commit_id=#{prev_commit.id};")
    if devfiles_of_prev_commit.size > 0
      ActiveRecord::Base.connection.execute("begin")
      now = DateTime.now
      devfiles_of_prev_commit.each do |df|
        if not changed_files.has_key?(df.path + df.name)
          begin
            sql = "insert into blobs_in_commits(blob_id, commit_id, created_at, updated_at) values('#{df['blob_id']}', '#{commit.id}', '#{now}', '#{now}');"
            ActiveRecord::Base.connection.execute(sql)
          rescue
            # do nothing
          end
        end
      end
      ActiveRecord::Base.connection.execute("commit")
    end
  end



def createBranch(uri, blob)
  begin
    
    puts "Creating branch".background(:green)
    
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
            version = "latest"
          end
        end
      end
    end
    
    @b_user = User.find_by_username(username)
    @b_device = User.find_by_username(username).devices.find_by_dev_name(devname)
    @b_devfile = @b_device.devfiles.find(:first, :conditions => ["name = ? and path = ?", filename, filepath])
    @b_blob = @b_devfile.blobs.find_by_version(version)
   
    #   @b_blob = Blob.find_by_sql("SELECT blobs.* 
    #                               FROM devfiles, blobs 
    #                               WHERE devfiles.device_id = '#{@b_device.id}'
    #                                 AND devfiles.id = blobs.devfile_id
    #                                 AND devfiles.name = '#{filepath}' AND devfiles.name = '#{filename}'
    #                                 AND devfiles.id = blobs.devfile_id
    #                                 AND blobs.version = '#{version}'")
    
    if @b_blob
      Branch.find_or_create_by_parent_blob_id_and_child_blob_id(@b_blob.id, blob.id)
    end
    puts "Also branch was created".background(:green)
    
  rescue => e
    puts "Errors in creating branch".background(:red)
    puts e
  end
  
end

# Tests if the device is reachable through http. If device is reachable, marks to db the ip-address
# where the request came from, and value direct_access to true. If device was not reachable
# marks direct_access as false.
#
# parameters: Method needs digest, the ip-address where the request came from and port.
def test_request(digest, rem_ip, port)
  device = Device.find_by_id_digest(digest)
  puts "-- Test_request on device " + device.dev_name + " (" + device.id.to_s + ")"
  address = nil
  i = 0
  while i < 2 do
      begin
        address = "http://" << rem_ip
        uri = URI.parse(address)
        if port != nil
          address << ":" << port.to_s
        else
          port = uri.port
        end
        puts "-- Timeout count #" + (i+1).to_s + " BEGIN on device: " + device.dev_name + " (" + device.id.to_s + "), " + address
        timeout(5 + 15*i) do
          Net::HTTP.start(uri.host, port) { |http|
            response = http.head(uri.path.size > 0 ? uri.path : "/")
          }
        i = 2
        end
        puts "-- Timeout count #" + (i+1).to_s + " END on device: " + device.dev_name + " (" + device.id.to_s + ")"
      rescue TimeoutError
        puts "-- TIMEOUT #" + (i+1).to_s + "on device: " + device.dev_name + " (" + device.id.to_s + ")"
        device.update_attribute(:direct_access, false)
        device.update_attribute(:address, nil)
        i += 1
        if i == 2
          return
        end
      rescue => exception
        puts exception
        puts "-- HTTP ERROR on device: " + device.dev_name + " (" + device.id.to_s + ")"
        device.update_attribute(:direct_access, false)
        device.update_attribute(:address, nil)
        return
      end
    end
    device.update_attribute(:direct_access, true)
    device.update_attribute(:address, address)
    
    ActiveRecord::Base.verify_active_connections!()
    puts "-- Test_request SUCCESSFUL on device: " + device.dev_name + " (" + device.id.to_s + "), " + address
  end
  
  
  # check if commit is missing (some of) it's thumbnails. Sends xmpp-messages to the device
  # for the missing thumbnails.
  #
  # parameters: commit - the commit in question
  #
  # @device has to be set.
  def checkForThumbs(commit) #:doc:
    prev_commit_blob_ids = Array.new
    prev_commit = Commit.find(:first, :conditions => ["id = ?", commit.previous_commit_id])
    if prev_commit
      prev_commit.blobs.find_each(:batch_size => 1500) do |pb|
        prev_commit_blob_ids.push(pb.id)
      end
    end
    
    blobs_without_thumb = Array.new
    new_thumbs = 0
    new_thumbs_without_thumb = 0
    prev_thumbs_ok = true
    commit.blobs.find_each(:batch_size => 1500) do |blob|
      if blob.thumbnail_name == nil and not prev_commit_blob_ids.include?(blob.id) and not blobs_without_thumb.include?(blob.blob_hash)
        blobs_without_thumb.push(blob.blob_hash)
        new_thumbs_without_thumb += 1
        new_thumbs += 1
      elsif blob.thumbnail_name == nil and not blobs_without_thumb.include?(blob.blob_hash)
        blobs_without_thumb.push(blob.blob_hash)
        prev_thumbs_ok = false
      elsif blob.thumbnail_name != nil and not prev_commit_blob_ids.include?(blob.id)
        new_thumbs += 1
      end
    end
    
    if blobs_without_thumb.size == 0 # we have all thumbs, do nothing
      return
    elsif prev_thumbs_ok and new_thumbs_without_thumb == new_thumbs # all new thumbs missing
      XmppHelper::sendXmppMessage(@device.xmppname, "thumbs " + commit.commit_hash)
    else
      # some thumbs are missing. get them.
      i = 0
      blobs_per_message = 100
      message = blobs_without_thumb[i...blobs_per_message]
      while message != nil do
        XmppHelper::sendXmppMessage(@device.xmppname, "thumbs " + commit.commit_hash + " " + message.join(" "))
        i += blobs_per_message
        message = blobs_without_thumb[i...blobs_per_message]
      end
    end  
  end
  
  
  # Checks that all necessary http parameters are given.
  #
  # parameters: username, password, devicename and dev_type. port is optionla, but if given must be a number.
  #
  # Returns false is some of the parameters is missing or is in wrong form.
  # Returns true if parameters are fine.
  #
  # register uses this method.
  def check_params #:doc:
    if params[:username] !~ /.{1,}/ or params[:password] !~ /.{1,}/ or
      params[:devicename] !~ /.{1,}/ or params[:dev_type] !~ /.{1,}/ or
      (params[:port] != nil and params[:port] !~ /\d{1,10}/)
      return false
    else
      return true
    end
  end
  
  
  
  
 
  


end