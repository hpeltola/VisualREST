require 'rubygems'
require 'net/http'
require 'mime/types'

class Multipart
 
  def initialize( file_path )
    @file_path = file_path
  end
 
  def post( to_url )
    boundary = '----RubyMultipartClient' + rand(1000000).to_s + 'ZZZZZ'
    
    parts = []
    pos = @file_path.rindex('/')
    filename = @file_path[pos + 1, @file_path.length - pos]
    stream = File.open(@file_path, "rb")
    contenttype = MIME::Types.type_for(filename).to_s
    parts << StringPart.new( "--" + boundary + "\r\n" +
      "Content-Disposition: form-data; name=\"" + "upload" + "\"; filename=\"" + filename + "\"\r\n" +
      "Content-Type: " + contenttype + "\r\n\r\n" )
    parts << StreamPart.new(stream, File.size(@file_path))
    
    parts << StringPart.new( "\r\n--" + boundary + "--\r\n" )
    
    post_stream = MultipartStream.new( parts )
    
    url = URI.parse( to_url )
    req = Net::HTTP::Post.new(url.path)
    req.content_length = post_stream.size
    req.content_type = 'multipart/form-data; boundary=' + boundary
    req.body_stream = post_stream
    res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
    
    stream.close()
    
    res
  end
 
end

class StreamPart
  def initialize( stream, size )
    @stream, @size = stream, size
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



filepath = "/home/leinon33/workspace/visualrest/public/testscripts/raksi2.jpg"
kekkuli = Multipart.new(filepath)
kekkuli.post("http://localhost:3000/user/metatest/device/mokku/upload")
