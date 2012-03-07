#
# Wraps http request and connecting. Switches ssl on if protocol is https.
# Calculates authentication hash with timestamp, password and path
#
# esim: res = HttpRequest.new(method, path, params).send(@@http_host)
#
class HttpRequest
  
  def initialize( method, path, params = {}, headers = nil, visualrestReq = true)

    #puts "params: #{params.to_s}"

    if method == :get
      @req = Net::HTTP::Get.new(path, headers)
    elsif method == :post
      @req = Net::HTTP::Post.new(path, headers)
    elsif method == :delete
      @req = Net::HTTP::Delete.new(path, headers)
    elsif method == :put
      @req = Net::HTTP::Put.new(path, headers)
    end
    
    if visualrestReq
    
      # authentication hash
     
      timestamp = Time.now.tv_sec
      params["auth_timestamp"] = timestamp
      #params[:auth_hash] = Digest::SHA1.hexdigest(timestamp.to_s + @@conf['password'] + path)
      
      params[:auth_hash] = Digest::SHA1.hexdigest(timestamp.to_s + @@xmpp_receive_password + path)
        
      # client flag
      params["i_am_client"] = "xmpp2rest"
      
    end
    
    @req.form_data = params
    
  end
  
  
  def send(to_url)
    uri = URI.parse(to_url)
    
    
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.ssl_timeout = 2
      
      # don't verify the certificate authenticity,
      # as nota.cs.tut.fi certificate is self signed
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    
    #return http.start {|ht| ht.request(@req) }
    
    res = nil
    i = 0
    while i < 3 do
      begin
        res = http.start {|ht| ht.request(@req) }
        i = 4
      rescue Errno::ECONNRESET => e
        puts e
        if i < 2
          puts "Trying again..."
        end
        sleep(0.5)
        i += 1
      rescue Timeout::Error => e
        puts e
        if i < 2
          puts "Trying again..."
        end
        sleep(0.5)
        i += 1
      end
    end
    
    
      
    if i == 3
      raise Exception.new("Can't establish connection to visualrest server! (localhost)")
    end
    if res.code.to_s == "417"
      raise Exception.new("Malformed uri. Code: #{res.code.to_s}, #{res.body.to_s}")
    elsif res.code.to_s == "302"  
      raise Exception.new("#{res.code.to_s}, #{res["location"]}")
    elsif res.code.to_s == "304"
      return res
      
    elsif res.code.to_s != "202" and res.code.to_s != "200" and res.code.to_s != "201"
      raise Exception.new("#{res.code.to_s}, #{res.body.to_s}")
    else
      return res
    end
    
  end # end for send method
  
  
  
  
end # http class end