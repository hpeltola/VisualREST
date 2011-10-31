require 'webrick'
require 'ftools'
require 'mime/types'
include WEBrick

class FileServlet
  
  class ContainsServlet < HTTPServlet::AbstractServlet
    
    
    @port = 0
    
    def parseFiles(current_dir, contains = "")
      if current_dir[current_dir.length - 1,1] != "/"
        current_dir += "/"
      end
      
      # parse files 
      Dir.foreach(current_dir) do |x|
        if x != '..' and x != '.' and x !~ /^\..*$/ and x != 'device_identity' and x != 'temp' and x != 'filelist.html' and x != 'client6.rb' and x != 'fileservlet80.rb' and x != 'fileservlet30.rb' and x != 'upload.rb' and x != 'fileservletall.rb'
          if not File.directory?(current_dir + x)

            stripdir = current_dir[2, current_dir.length - 2]
            contains += stripdir + '<a class="file" href="/' + stripdir + "#{x}" + '">' + "#{x}" +
                      '</a> <a name="size_' + stripdir + "#{x}" + '">' + File.size(current_dir + x).to_s +
                      '</a> <a name="time_' + stripdir + "#{x}" + '">' +
            File.mtime(current_dir + x).strftime('%T %F').to_s + "</a><br/>" + "\n"
          end
        end
      end
      
      # parse dirs
      Dir.foreach(current_dir) do |x|
        if x != '..' and x != '.' and x !~ /^\..*$/ and x != 'device_identity' and x != 'temp' and x != 'filelist.html' and x != 'client6.rb' and x != 'fileservlet80.rb' and x[0,1] != '.' and x != 'vR_default_thumbnails'              
          if File.directory?(current_dir + x)
            
            contains = parseFiles(current_dir + x, contains)
          end
        end
      end
      
      return contains
    end
    
    

    
    
    
    def do_GET(request,response)
#      puts RUBY_PLATFORM
#      puts ENV['OS']
      
#      puts('---------------here-----------')
#      puts('the options are' + "#{@options[0]}")
      complete_path = request.path.split("/")
      depth_of_path = complete_path.length
      
#      puts("urin syvyys on: #{depth_of_path} missä ne ovat #{complete_path[0]} ja #{complete_path[1]} ja #{complete_path[2]} ja #{complete_path[3]}")  
      basedir = "."
      current_dir = basedir
#      puts("the current dir BEFORE the loop is: #{current_dir} and depth of path is : #{depth_of_path}")  
      if depth_of_path >= 2
        complete_path.delete_at(0)
        for i in 0..(complete_path.length - 1) 
          if i == (complete_path.length - 1)
            if File.directory?("#{current_dir + ('/'+ complete_path[i] + '/')}") then current_dir += ('/'+ complete_path[i] + '/') else current_dir += ('/'+ complete_path[i]) end
#            puts("for loop should end and this is final uri: #{current_dir} at iteration: #{i}")
          else
            current_dir += ('/'+ complete_path[i])
#            puts("the current dir in for loop is: #{current_dir} at iteration: #{i}")
          end
        end
        
#        puts("current dir is now----------------: #{current_dir}")
      else
        current_dir += ('/')
#        puts("current dir should be basedir: #{current_dir}")
      end
      if File.directory?("#{current_dir}") == true
        contains = '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN"
       "http://www.w3.org/TR/html4/strict.dtd">
       
    <html lang="en">
    <head>
    	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    	<title>All my Pictures</title>
    	<meta name="generator" content="TextMate http://macromates.com/">
    	<meta name="author" content="Juha Savolainen">
    	<!-- Date: 2009-05-09 -->
    </head>
    <body>'
        
    
   # parse files
   contains += parseFiles(current_dir)
   contains += '</body>
    </html>
    ' 
  #      puts contains
        response.body = contains
      else
        begin
          displayfile = File.open(current_dir, 'r')
          content = displayfile.read()
          response.body = content
        rescue Errno::ENOENT
          puts("File not found")
        end
      end
      
    end
  end
  
  def initialize( port )
    @port = port
    
  end
  

  
  
  
  
  def start
    
    # Norlmal server
    #@@server = HTTPServer.new(:Port => @port)
    
    # Server that doesnt print log messages
    @@server = HTTPServer.new(:Port => @port,
                              :Logger => Log.new(nil, BasicLog::WARN),
                              :AccessLog => []
    )
    
    @@server.mount('/',  ContainsServlet, '/')
    @@server.start
    
  end
  
  def stop
    @@server.stop
  end
  

  
  
end

