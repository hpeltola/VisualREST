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
  
  
  
#  def putsE(e)
#      puts "DropBox Helper Error: #{e.to_s}"
#      puts "  -- line: #{e.backtrace[0].to_s}"
#  end
  
  
  
end