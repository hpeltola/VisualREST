class DropboxHelper
  
  
  def initialize(user)
    
    @user = user
    @si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ?", @user.id, "dropbox"])
    
    @max_retry = 5
    
    @dropbox_host = @@dropbox_host
    @db_app_id = @@db_app_id
    @db_app_secret = @@db_app_secret
    
  end
  
  
  
  def getMetadatas(path)
    
      if @si
        @db_auth_token = @si
        
        filepath = "/metadata/dropbox" + path
        i = 0
        begin
          path = dbCalculateSignaturedPath(@@dropbox_host,filepath,@si,true)
          res = HttpRequest.new(:get, path).send(@dropbox_host)
          #puts "res code: " + res.code.to_s
          #puts "res body: " + res.body.to_s
   
          if res.code.to_s == "200"
            info = JSON.parse(res.body)
            return info
          else
            #puts res.code.to_s + " : " + res.body.to_s
            info = JSON.parse(res.body)
            return info
          end
        
        rescue Exception => e
          #putsE(e)
          i += 1
          if i == @max_retry
            puts "Retry: #{i.to_s}  (max #{@max_retry.to_s})"
          end
          sleep(0.5)
          if i < @max_retry
            retry
          else
            raise Exception.new("MaxRetryTimes1")
          end
        end

      else
        raise Exception.new("No service information was found!")
      end
  end
  
  
  
  
  def dbCalculateSignaturedPath(host, filepath, si, list = false)
    
    oauth_consumer_key = @@db_app_id
    consumer_secret = @@db_app_secret
    
    oauth_token = si.s_token 
    token_secret = si.s_id 
    
    ts = Time.now.to_i.to_s
    
    
    nonce = rand(7).to_s + ts.to_s
#    puts "nonce: #{nonce}"
    filepath = "/0" + URI.escape(filepath) #filepath
    
    params = "oauth_consumer_key=#{oauth_consumer_key}&oauth_nonce=#{nonce}&oauth_signature_method=HMAC-SHA1&oauth_timestamp=#{ts}&oauth_token=#{oauth_token}"
    if list
      params = "list=true&" + params
    end
    
    bs = "GET&" + URI.escape("#{host}#{filepath}", Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")) + '&' + URI.escape(params, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    
    # Special cases:
    bs = bs.gsub("(", "%2528")
    bs = bs.gsub(")", "%2529")
    
    #puts "bs: #{bs}"
    
    secret="#{consumer_secret}&#{token_secret}"
    s = Base64.encode64(HMAC::SHA1.digest(secret,bs)).chomp.gsub(/\n/,'')
 
    path = "#{filepath}?oauth_consumer_key=#{oauth_consumer_key}&oauth_nonce=#{nonce}&oauth_signature_method=HMAC-SHA1&oauth_timestamp=#{ts}&oauth_token=#{oauth_token}&oauth_signature=#{s}"
    if list
      path += "&list=true"
    end
#puts "PATH: #{path}".background(:green)
    return path
  end
  
  
  
  
  
  
  
  
  
  
  
  def downloadFile(path)
    
      if @si
        @db_auth_token = @si
        
        filepath = "/files/dropbox" + path
        i = 0
        begin
          path = dbCalculateSignaturedPath(@@dropbox_content_host,filepath,@si)
          res = HttpRequest.new(:get, path).send(@@dropbox_content_host)
          #puts res.code.to_s
          
          if res.code.to_s == "200"
            return res.body
          else
            #puts res.code.to_s + " : " + res.body.to_s
            return raise Exception.new(res.code.to_s + " : " + res.body.to_s)
          end
        
        rescue Exception => e
          #putsE(e)
          i += 1
          if i == @max_retry
            puts "Retry: #{i.to_s} (max #{@max_retry.to_s} times)"
          end
          sleep(0.5)
          
          if i < @max_retry
            retry
          else
            raise Exception.new("MaxRetryTimes2")
          end
        end

      else
        raise Exception.new("No service information was found!")
      end
  end
  
  
  
  
  
  
  
  
  
  
  
  private
  
  
  
  def putsE(e)
      puts "DropBox Helper Error: #{e.to_s}"
      puts "  -- line: #{e.backtrace[0].to_s}"
  end
  
  
  
end