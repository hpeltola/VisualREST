require 'rubygems'
require 'net/http'
require 'net/https'
require 'mime/types'

# Make a multipart http request and send the file
# Calculates the authentication hash with timestamp, password and path
class Multipart
 
  def initialize( file_path )
    @file_path = file_path
  end
 
  def put( to_url, rel_path, stream, stream_size, blob_hash, thumbnail = false )
    begin
    boundary = '----RubyMultipartClient' + rand(1000000).to_s + 'ZZZZZ'
    
    parts = []
    pos = @file_path.rindex('/')
    filename = @file_path[pos + 1..-1]
    
    url = URI.parse( to_url )
    auth_timestamp = Time.now.tv_sec
    if @@conf
      auth_hash = Digest::SHA1.hexdigest(auth_timestamp.to_s + @@conf['password'] + url.path)
    else
      auth_hash = "0"
    end
    
    # client flag
    parts << StringPart.new( "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"i_am_client\"" + "\r\n\r\n" )
    parts << StringPart.new("true" + "\r\n")
    
    # auth_timestamp
    parts << StringPart.new( "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"auth_timestamp\"" + "\r\n\r\n" )
    parts << StringPart.new(auth_timestamp.to_s + "\r\n")
    
    # auth_hash
    parts << StringPart.new( "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"auth_hash\"" + "\r\n\r\n" )
    parts << StringPart.new(auth_hash + "\r\n")

    # thumbnail
    if thumbnail
      parts << StringPart.new( "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"thumbnail\"" + "\r\n\r\n" )
      parts << StringPart.new(rel_path + "\r\n")
      stream = File.open(@file_path, "rb")
      stream_size = File.size(@file_path)
    end

    # blob-hash
    parts << StringPart.new( "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"blob_hash\"" + "\r\n\r\n" )
    parts << StringPart.new(blob_hash + "\r\n")

    # upload
    contenttype = MIME::Types.type_for(filename).to_s
    parts << StringPart.new( "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"upload\"; filename=\"#{filename}\"" + "\"\r\n" +
      "Content-Type: " + contenttype + "\r\n\r\n" )
    parts << StreamPart.new(stream, stream_size)
    
    parts << StringPart.new( "\r\n--" + boundary + "--\r\n" )
    
    post_stream = MultipartStream.new( parts )
    
    
    # create http request
    request = Net::HTTP::Put.new(url.path)
    request.content_length = post_stream.size
    request.content_type = 'multipart/form-data; boundary=' + boundary
    request.body_stream = post_stream
    
    # create http connection and send request
    http = Net::HTTP.new(url.host, url.port)
    if url.scheme == 'https'
      http.use_ssl = true
      http.ssl_timeout = 2
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    http.start {|ht| ht.request(request) }
    
    stream.close()
  rescue => exception
    puts exception
    end
    #res
  end
 
end

class StreamPart
  def initialize( stream, size )
    @stream, @size = stream, size
  end
  
  def print
    puts @stream
  end
 
  def size
    @size
  end
 
  def read( offset, how_much )
    @stream.read( how_much )
  end
end

class StringPart
  def initialize ( str )
    @str = str
  end
  
  def print
    puts @str
  end
 
  def size
    @str.length
  end
 
  def read( offset, how_much )
    @str[offset, how_much]
  end
end

class MultipartStream
  def initialize( parts )
    @parts = parts
    @part_no = 0;
    @part_offset = 0;
  end
 
  def size
    total = 0
    @parts.each do |part|
      total += part.size
    end
    total
  end
 
  def read( how_much )
   
    if @part_no >= @parts.size
      return nil;
    end
   
    how_much_current_part = @parts[@part_no].size - @part_offset
   
    how_much_current_part = if how_much_current_part > how_much
      how_much
    else
      how_much_current_part
    end
   
    how_much_next_part = how_much - how_much_current_part
   
    current_part = @parts[@part_no].read(@part_offset, how_much_current_part )

    if how_much_next_part > 0
      @part_no += 1
      @part_offset = 0
      next_part = read( how_much_next_part  )
      current_part + if next_part
        next_part
      else
        ''
      end
    else
      @part_offset += how_much_current_part
      current_part
    end
  end
end


# Wraps http request and connecting. Switches ssl on if protocol is https.
# Calculates authentication hash with timestamp, password and path
class HttpRequest
  
  def initialize( method, path, params = {}, headers = nil)

    if method == :get
      @req = Net::HTTP::Get.new(path, headers)
    elsif method == :post
      @req = Net::HTTP::Post.new(path, headers)
    elsif method == :delete
      @req = Net::HTTP::Delete.new(path, headers)
    elsif method == :put
      @req = Net::HTTP::Put.new(path, headers)
    end
    
    # authentication hash
    if @@conf
      timestamp = Time.now.tv_sec
      params["auth_timestamp"] = timestamp
      params[:auth_hash] = Digest::SHA1.hexdigest(timestamp.to_s + @@conf['password'] + path)
    else
      params["auth_hash"] = "0"
    end
    
    # client flag
    params["i_am_client"] = "true"
    
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
    
    return http.start {|ht| ht.request(@req) }
  end
end






