require 'rubygems'
require 'net/http'
require 'net/https'
require 'mime/types'
require 'trollop'

# Read commandline arguments
@@opts = Trollop::options do
  opt :path, "Change path", :default => '/user/heikki/contexts/Hervanta', :type => String
  opt :uri, "Change uri", :default => 'http://localhost:8080/', :type => String
  opt :username, "Change username", :default => 'heikki'
  opt :password, "Change password", :default => 'heikki'
  opt :method, "Change request method", :default => 'put'
  opt :parameters, "Change params", :default => "&metadata=tag/England+tag/rain+tag/bus&begin_time=2007-01-01&end_time=2070-01-03&location=Hervanta&user=kalle+john&group=ryhmax", :type => String
end

# Use get, post, delete or put method
if @@opts[:method] == 'get'
  @req = Net::HTTP::Get.new(@@opts[:path])
elsif @@opts[:method] == 'post'
 @req = Net::HTTP::Post.new(@@opts[:path])
elsif @@opts[:method] == 'delete'
 @req = Net::HTTP::Delete.new(@@opts[:path])
elsif @@opts[:method] == 'put'
 @req = Net::HTTP::Put.new(@@opts[:path])
else
  puts "Invalid method"
  exit
end

params = {}
    
# timestamp that auth_hash is calculated with
timestamp = Time.now.tv_sec
params["auth_timestamp"] = timestamp

# Calculate authentication hash
params[:auth_hash] = Digest::SHA1.hexdigest(timestamp.to_s + @@opts[:password] + @@opts[:path])

# Give username and i_am_client parameters
params["auth_username"] = @@opts[:username]
params["i_am_client"] = "true"

# Process search parameters
parameters = @@opts[:parameters].split('&')
parameters.each do |x|
  type, value = x.split('=')
  if type and value
    params[type] = value
  end
end  
    
@req.form_data = params



## Make http request

uri = URI.parse(@@opts[:uri])
    
    
http = Net::HTTP.new(uri.host, uri.port)
if uri.scheme == 'https'
  http.use_ssl = true
  http.ssl_timeout = 2
  
  # don't verify the certificate authenticity,
  # as nota.cs.tut.fi certificate is self signed
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
end

res = http.start {|ht| ht.request(@req) }

# Show response from server
puts res
puts
puts "Response code: #{res.code}"

## Show all parameters that request was made with
puts "path: #{@@opts[:path]}"
puts "uri: #{@@opts[:uri]}"
puts "method: #{@@opts[:method]}"
puts "username: #{@@opts[:username]}"
puts "password: #{@@opts[:password]}"
puts "parameters: #{@@opts[:parameters]}"

