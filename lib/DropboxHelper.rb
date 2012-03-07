class DropboxHelper
  
  
  def initialize(user)
    
    @si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ?", user.id, "dropbox"])
    if not @si
      raise Exception.new("No service information was found in Dropboxhelper!")
    end 
    
    # URL:s to dropbox api and content_host
    @dropbox_api_host = @@dropbox_host
    @dropbox_content_host = @@dropbox_content_host
    
    # Consumer key and secret
    @db_consumer_key = @@db_app_id
    @db_consumer_secret = @@db_app_secret
    
    # OAuth token and scret
    @db_oauth_token = @si.auth_token
    @db_oauth_token_secret = @si.auth_secret
      
  end
  
  
  
  def getUserInfo
    
    begin
      path = "/1/account/info"
      header = getOAuthParams(@dropbox_api_host)
     
      res = HttpRequest.new(:get, path, {}, header, false).send(@dropbox_api_host)
        
      return JSON.parse(res.body)
    
    rescue Exception => e
      puts "ERROR: DropboxHelper, getUserInfo()"
      puts e
      return "ERROR"
    end
    
  end
  
  
  
  def getMetadatas(filepath, parameters = nil)
    
    begin
      path = "/1/metadata/dropbox" + filepath
      header = getOAuthParams(@dropbox_api_host)
      
      if parameters != nil
        path += '?' + parameters
      end

      res = HttpRequest.new(:get, path, {}, header, false).send(@dropbox_api_host)
      

#      puts "GET metadatas code: #{res.code.to_s}"
#      puts JSON.pretty_generate(JSON.parse(res.body))
      return JSON.parse(res.body)
      
    rescue Exception => e
      puts "ERROR: DropboxHelper, getMetadatas(#{filepath})"
      puts e
      raise Exception.new("ERROR: getMetadatas in DropboxHelper!")
    end
  end
  
  
  
  def downloadFile(filepath)
        
    begin

      path = "/1/files/dropbox" + filepath
      header = getOAuthParams(@dropbox_content_host)
        
      res = HttpRequest.new(:get, path, {}, header, false).send(@dropbox_content_host)
          
      if res.code.to_s == "200"
        return res.body
      else
        return raise Exception.new(res.code.to_s + " : " + res.body.to_s)
      end
        
    rescue Exception => e
      raise Exception.new("Error downloading file") 
    end
  end
 
  def uploadFile(dropbox_path, file_uri)
    
    begin
      
      path = "/1/files/dropbox" + dropbox_path

       # The file_uri points to a file in VisualREST
      @devfile = getDevfileFromURI(file_uri)
           
      @device = Device.find_by_id(@devfile.device_id)
           
      
      @blob = Blob.find_by_id(@devfile.blob_id)
      if @blob.uploaded == false
        raise Exception.new('The file is not uploded on the server')
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
  
        path_to_file = "private/temp#{@devfile.path}#{@devfile.name}"
        if not (File.exists?("private/temp#{@devfile.path}") && File.directory?("private/temp#{@devfile.path}"))
          FileUtils.mkdir_p("private/temp#{@devfile.path}")      
        end 
        # Save from git to a file in path 'path_to_file'
        File.open(path_to_file, "wb") { |f|   
          f.write(repoBlob.data)
        }
      end
    
      url = URI.parse( @@dropbox_content_host + path )

      File.open(path_to_file) do |photo|

        # Get all authentication parameters
        oauth_consumer_key, oauth_nonce, oauth_signature_method, oauth_signature, oauth_timestamp, oauth_version, oauth_token = getOAuthParamsSeparately()

        req = Net::HTTP::Post::Multipart.new( url.path,
          "file" => UploadIO.new(photo, @devfile.filetype, @devfile.name), 'oauth_consumer_key' =>oauth_consumer_key, 
                                                                           "oauth_nonce"=>oauth_nonce, 
                                                                           "oauth_signature_method"=>oauth_signature_method, 
                                                                           "oauth_signature"=>oauth_signature, 
                                                                           "oauth_timestamp"=>oauth_timestamp, 
                                                                           "oauth_version"=>oauth_version, 
                                                                           "oauth_token"=>oauth_token)
          
        http = Net::HTTP.new(url.host, url.port)
        if url.scheme == 'https'
          http.use_ssl = true
          http.ssl_timeout = 2  
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        res = http.start {|ht| ht.request(req) }
      
        # Check if the file is added to Dropbox from response
        if res.code.to_s != "200"
          raise Exception.new("Could not upload to Dropbox, code: #{res.code.to_s}")
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
      puts "ERROR: DropboxHelper, uploadFile:(#{dropbox_path} ::: #{file_uri})"
      puts e.to_s
      raise Exception.new("Error uploading file to Dropbox") 
      
    end
    
  end
   
  
  private
  
  def getOAuthParams(realm)
    
    timestamp = Time.now.to_i
    nonce = rand(10 ** 30).to_s.rjust(30,'0')     
    signature = @db_consumer_secret + "%26"  + @db_oauth_token_secret
    
    head_params = 'OAuth realm="'+ realm +'", ' + 
                  'oauth_consumer_key="' + @db_consumer_key + '", ' +
                  'oauth_nonce="'+ nonce + '", ' +
                  'oauth_signature_method="PLAINTEXT", ' +
                  'oauth_signature="'+ signature +'", ' +
                  'oauth_timestamp="'+ timestamp.to_s + '", ' + 
                  'oauth_version="1.0", ' +
                  'oauth_token="'+ @db_oauth_token + '"'          
                 
    header = { 'Authorization' => head_params} 
    return header
  end
  
  
  # The order of parameters to return: oauth_consumer_key, oauth_nonce, oauth_signature_method,
  #                                    oauth_signature, oauth_timestamp, oauth_version, oauth_token
  def getOAuthParamsSeparately()
    timestamp = Time.now.to_i
    nonce = rand(10 ** 30).to_s.rjust(30,'0')     
    signature = @db_consumer_secret + "&"  + @db_oauth_token_secret
    
    oauth_consumer_key= @db_consumer_key
    oauth_nonce=nonce
    oauth_signature_method="PLAINTEXT"
    oauth_signature=signature
    oauth_timestamp=timestamp.to_s
    oauth_version="1.0"
    oauth_token=@db_oauth_token          
                 

    return oauth_consumer_key, oauth_nonce, oauth_signature_method, oauth_signature, oauth_timestamp, oauth_version, oauth_token
  end
  
  
  def getDevfileFromURI(uri)
    username, devicename, filepath, filename, version = parseFileInfoFromURI(uri)
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
  
  
 
  
  
end