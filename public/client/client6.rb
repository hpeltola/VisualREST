require "date"
require "uri"
require 'upload.rb'
require 'rubygems'
require 'net/http'
require 'net/https'
require 'open-uri' 
require 'mime/types'
require 'xmpp4r/roster'
require 'xmpp4r/callbacks'
require 'xmpp4r'
require 'xml/libxml'
require 'progressbar'

require 'fileservlet80.rb'
require 'gitusage.rb'
require 'location.rb'

require 'ftools'
require 'rubygems'
require 'yaml'
require 'trollop'

require 'gd2'
include GD2 


# Default values should be changed from here:
@@opts = Trollop::options do
  opt :port, "Change your server port.", :default => 2000
  opt :host, "Change visualREST server.", :default => "http://nota.cs.tut.fi:8080"
  opt :mode, "Change location mode. Use GPS with Nokia N810. Possible values are noGPS, noGPS1 and GPS", :default => "noGPS"
  opt :active_check, "Active checking for changes in filelist. Give checking time in seconds.", :default => 15
  opt :test_messages, "Prints test messages if any", :default => false
  opt :online_report, "Changes how often client reports that it is online. No reporting, value is 0.", :default => 60
end

@@t = nil

begin
  @@conf = YAML::load File.new('device_identity')
rescue
  puts "Couldn't load config file"
  @@conf = nil
end



# set by checkOpts method
@@self_port = 0
@@host = ""

@@location = Location.new(@@opts[:mode]) #updateLocation #{'latitude' => "23.75", 'longitude' => "61.75"}

puts "Creating index of your files..."
@@gitusage = GitUsage.new(@@location.getLocation)
puts "Done!"
@@waiting_for_parse_confirmation = false

@@nikkis_ip = "localhost"     #"130.230.144.182"

@@xmpp_host = "nota.cs.tut.fi"

@@xmpp_port = 5222
@@visualRESTmain = "visualrestmain_niko@" + @@xmpp_host + "/main"

@@servlet = nil
@@test_messages = false  # set by checkOpts
# How long threads sleep before they start running
@@threadSleep = 20

@@threadIDs = Hash.new

['TERM','INT'].each do |signal|
  trap(signal){

    puts "\nStopping..."
    exit
  }
end



@@status = Hash.new

@@cookie = nil


# Connect to jabber server and define callback
def runJabber
  
  i = 0
  while i < 3 do 
    begin
      @jbclient = Jabber::Client.new Jabber::JID.new(@@conf["jabber_account"])
      @jbclient.connect(@@xmpp_host, @@xmpp_port)
      @jbclient.auth(@@conf["password"])
      @jbclient.send(Jabber::Presence.new.set_type(:available))
      puts "Connected to jabber server" if @jbclient.is_connected?
      
      roster = Jabber::Roster::Helper.new(@jbclient)
      
      roster.add_subscription_request_callback { |item,presence|
        if presence.from == @@visualRESTmain
          roster.accept_subscription(presence.from)
        end
      }
      i = 3
    rescue => exception
      puts "xmpp " + exception
      sleep(1)
      i += 1
    end
  end
  
  @jbclient.add_message_callback { |msg|
    if msg != nil and msg.type == :chat and msg.body and msg.from == @@visualRESTmain
      puts "<#{msg.from}> #{msg.body.strip}"
      
      cmd, arg = msg.body.split(/ /, 2)
      
      if cmd and @@test_messages
        puts "CMD: " + cmd
      end
      if arg and @@test_messages
        puts "ARG: " + arg
      end
      command(msg.from, cmd, arg)
    end
  }
end


# Method which runs the fileservlet 
def runFileServer
  @@servlet = FileServlet.new(@@self_port)
  
  Thread.start {
    @@servlet.start()  
  }
  
end

def cmdLine
  print '> '
end


def command(from, cmd, arg)
  cmd.downcase!
  
  case cmd
    when 'info'
    puts "\nDevice name: " + @@conf['dev_name']
    puts "Username: " + @@conf['username']
    puts "Jabber account name: " + @@conf['jabber_account']
    
    
    when 'list'
    # Creates list of the files and send it to main server
    #parsefilelist()
    if arg
      submitFilelist(arg)
    else
      submitFilelist
    end
    
    when 'print'
    printFiles
    
    when 'upload'
    args = arg.split(/ /, 2)
    if args[0] != nil and args[1] != nil and not args[0].empty? and not args[1].empty?
      uploadfile(args[0], args[1], false)
    end
    
    # command for testing visualREST REST api - begin
    when 'deletefile'
    deleteFileFromServer(arg)
    
    when 'addgroup'
    addGroupToServer(arg)
    
    when 'deletegroup'
    deleteGroupFromServer(arg)

    when 'doo' # does not work with https currently
    doo(arg)
    
    when 'uppaa'
    uploadBlob
    
    when 'testi'
    t
    
    when 'put'
    put(arg)
    
    when 'active', 'ac'
    activeChecking(@@opts[:active_check])
    
    when 'delete'
    delete(arg)
    
 # command for testing visualREST REST api - end
 
    when 'getfile'
    getFile(arg)
 
 # testing commands end
    when 'exit'
    puts "Stopping..."
    #Thread.stop
    puts "................."
    exit
    
    when 'parse'
    if arg =~ /^\w+ \w+/
      args = arg.split(/ /, 2)
      if args[0] == 'successful'
        puts "Filelist of commit with id=" + args[1] + " has been updated to the server!"
        @@gitusage.commitReported(args[1])
      else
        puts "Error: Malformed filelist! Please use command 'list' to send filelist again."
      end
      if @@gitusage.getOldestUnreportedCommit
        submitFilelist
      else
        @@waiting_for_parse_confirmation = false
      end
    end
    when 'ping'
    online

    if @@test_messages 
      puts "pong"
    end
    
    when 'threads', 'th'
    threadTest
    
    when 'thumb'
    if arg
      args = arg.split(/ /, 2)
      if args[0] != nil and args[1] != nil and not args[0].empty? and not args[1].empty?
        Thread.new{
          createAndUploadThumbnail(args[0], args[1])
        }
      end
    end
  
    when 'thumbs'
    Thread.new do
      if arg
        args = arg.split(" ")
        if args.size == 1
          generateThumbnails(arg)
        elsif args.size > 1
          puts "1111"
          generateThumbnailsOfBlobs(args[1..-1], args[0])
          puts "XXXX"
        end
      else
        generateThumbnails
      end
    end
  end
end





# Methods for testing visualREST REST api

# Deletes file from server
def deleteFileFromServer(filepath)
  filepath = filepath[1, filepath.length - 1]  
  address = @@host + "/user/" + @@conf["username"] + "/device/" + @@conf["dev_name"] + "/files/" + filepath
  
  res = HttpRequest.new(:delete, address).send(@@host)  
  puts res
  puts "CODE: " + res.code

end

# Deletes file from server
def addGroupToServer(group)
  path = "/user/" + @@conf["username"] + "/group/" + group.strip
  res = HttpRequest.new(:put, path).send(@@host)
  puts res
  puts "CODE: " + res.code

end

def deleteGroupFromServer(group)
  path = "/user/" + @@conf["username"] + "/group/" + group.strip
  res = HttpRequest.new(:delete, path).send(@@host)
  puts res
  puts "CODE: " + res.code
end


def put(path)
  puts "PUT: " + path
  res = HttpRequest.new(:put, path).send(@@host)
  puts res
  puts "CODE: " + res.code
end

def delete(path)
  puts "DELETE: " + path
  res = HttpRequest.new(:delete, path).send(@@host)
  puts res
  puts "CODE: " + res.code
end

def doo(arg)
  if arg.empty?
    puts "Usage: method + path *( + name=>value )"
    return
  end
  args = arg.split(/ /)
  if args.length < 2
    puts "Usage: method + path *( + name=>value )"
    return
  end
  method = args[0].strip
  args.delete_at(0)
  path = args[0]
  args.delete_at(0)
  
  method.downcase!
  puts method + ": " + @@host + path
  
  params = []
  args.each do |p|
    k, v = p.split(/=>/)
    #puts "k: " + k
    #put "v: " + v
    params.merge!({k.strip => v.strip})    
  end
  
  
  request = HttpRequest.new( :post, path, params ) if method == 'post'
  request = HttpRequest.new( :put, path, params ) if method == 'put'
  request = HttpRequest.new( :delete, path, params ) if method == 'delete'
  request = HttpRequest.new( :get, path, params ) if method == 'get'
  res = request.send(@@host)
  
  puts res
  puts "CODE: " + res.code
  return res
end

def threadTest
  puts "Current thread = " + Thread.current.to_s
  i = 1
  Thread.list.each {|thr| 
    print ' ' + i.to_s + '. '
    i += 1
    print thr 
    name = @@threadIDs[thr.to_s]
    if name != nil
      print " --- " + name
    end
    puts ""
  }  
  puts ""  
end


def online
  puts "online"
  
  path = "/user/#{@@conf["username"]}/device/#{@@conf["dev_name"]}/online"
  params = {}
  
  location = YAML.dump_stream(@@location.getLocation)
  if location != nil
    @@status.merge!({'device_location' => location})
  end
  
  if @@status != nil
    params.merge!({ 'status' => YAML.dump_stream(@@status)})
  end
  
  
  
  
  # If sessio_id cookie is already set, sets it to headers, 
  # so that the session can be remembered on the server side.
  if @@cookie != nil
    headers = {
      'Cookie' => @@cookie,
    }
  end
  
  # Response from online report.
  res = HttpRequest.new(:post, path, params, headers).send(@@host)
  
#  # Sets sessio-id cookie from response, if not already set.
#  if @@cookie == nil
#    @@cookie = res.response['set-cookie'].split('; ')[0]
#  end
  
  # Print session id if test_messages are set on with start-up paramete
  if @@test_messages
    puts "Vastaus:"
    puts "Cookie, sessio_id: " + @@cookie.to_s
    puts "Loppu"
  end

  return res
end



def checkType(name)
  type = "unknown"
      
    if not MIME::Types.type_for(name).to_s.empty?
        type = MIME::Types.type_for(name).to_s
    end
    return type
end

def t
  path = "/user/testikkeli/device/vimpain/files/test.txt?hh=2&version=0"
  
 
  username = nil
  device = nil
  filepath = "/"
  filename = nil
  version = "latest"
  
  parts = path.split(/\//, 7)
  
  parts.each_with_index do |p, i|
    puts p
    if p == 'user' and parts.count > i+1
      username = parts[i+1]
    elsif p == 'device' and parts.count > i+1
      device = parts[i+1]
    elsif p == 'files' and parts.count > i+1
      file = parts[i+1]
      puts "file: " + file
      
      filepath = file.split(/[^\/]+$/)[0]
      if not filepath
        filepath = "/"
      end
      # eka/toka/test.txt?version=0
      
      filename = file[/[^\/]+$/].split(/\?/)[0]
      params = file.split(/\?/, 2)
      
      if params.count > 1
        puts "params: " + params[1]
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
      
      
#      
#     if file.split(/\?/).count > 1
#       version = (file.split(/\?/)[1])[/[^=]*$/]
#     else
#       version = "latest"
#     end
    end
  end
  
  
  
  puts "UNAME: " + username
  puts "device: " + device
  puts "filepath: " + filepath
  puts "filename: " + filename
  puts "version: " + version
  
end


def getFile(arg)
  
  begin
    if arg == nil or arg.empty?
      puts "No args given"
      return
    end
    
    args = arg.split(/ /)
    
    uri = args[0]
    args.delete_at(0)
    
    uri = URI.parse(uri)
    
    res = HttpRequest.new(:get, uri.path).send(uri.to_s)
    
    if res.code == "200"
      
      # If file was downloaded successfully, saves it
      save_path = "/Downloads/"      
      
      # create dir if it does not exist
      if not (File.exists?(save_path) && File.directory?(save_path))
        FileUtils.mkdir_p(save_path)
      end
      
      filename = uri.path[(uri.path.rindex('/')+1)..-1]
      
      puts "Filename: " + filename.to_s
      
      path = save_path + filename
      
      readfrom = res.body
      
      if readfrom != nil

        # write the file
        File.open('.'+path, "wb") { |f|   
          puts f.to_s
          f.write(readfrom) }
        puts "File " + filename + " created."
      end
      puts "File downloaded and saved!"
      
      # Adds file to git and creates metainfo about the files origin
      @@gitusage.createTraceToVR(uri, path, @@location.getLocation)
 
    else
      puts "Error in fetching file! Code: " + res.code.to_s
    end

    
  rescue => e
    puts e
  end
  
end







def printFiles  
  filelist = @@gitusage.getFilelistOfCommit
  
  # Tiedostolistaus voidaan tulostaa näin
  puts "Found " + filelist.length.to_s + " files"
  
  filelist.each do |t|
    puts "------------------------------------------------"
    puts "avain (koko nimi): " + t.first
    
    puts "nimi: " + t.last["name"].to_s
    puts "polku:" + t.last["path"].to_s
    puts "koko: " + t.last["size"].to_s
    puts "aika: " + t.last["filedate"].to_s 
  end
end


def scale(i)
  
  #  widthx = 128
  #  heightx = 128 
  #  
  #  if i.size[0] > i.size[1]  # Horizontal proportion. width > height.
  #    if i.size[0] < widthx then width = i.size[0]     # preffer smaller image width
  #    else width = widthx
  #    end
  #    
  #    height = width * i.size[1] / i.size[0]
  #    
  #  else                      # Vertical proportions
  #    if i.size[1] < heightx then height = i.size[1]
  #    else height = heightx
  #    end
  #    
  #    width = i.size[0] /(i.size[1] / height) 
  #  end
  #  
  #  i.resize! width, height
  i.resize! 128, 128
  
  return i
end



def generateThumbnail(blob)
  vR_default_thumbnail_path_base = "./vR_default_thumbnails/"
  vR_default_thumbnail_file = "vR_unknown.png"
  if blob
    contenttype = MIME::Types.type_for(blob.name).to_s
    filename = blob.name
    name = ".temp." + filename
    begin
      thumb = nil
      if contenttype == "image/jpeg" or contenttype == "image/png" or contenttype == "image/gif"
        img = Image.load(blob.data)
        thumb = scale(img)
        thumb.export('./' + name)
        return name
        
      elsif contenttype == "video/x-msvideo"
        format = filename.split(".").last
        if format == 'avi'
          vR_default_thumbnail_file = "vR_avi.png"
        elsif format == 'mov'
          vR_default_thumbnail_file = "vR_mov.png"
        end
        
      elsif contenttype == "application/mswordapplication/x-mswordapplication/x-wordapplication/wordtext/plain"
        vR_default_thumbnail_file = "vR_doc.png"
      elsif contenttype == "application/x-ruby"
        vR_default_thumbnail_file = "vR_ruby.png"
      elsif contenttype == "text/plain"
        vR_default_thumbnail_file = "vR_txt.png"
      else
        vR_default_thumbnail_file = "vR_unknown.png"
      end
      from = vR_default_thumbnail_path_base + vR_default_thumbnail_file
      name += ".vR_unknown.png"
      File.copy(from, name)
      return name
      
    rescue => exception
      puts "Thumbnail creation failed!"
      puts exception
    end
    
  else 
    puts "blobia ei ole"
  end
  
  
end


=begin

Toimiva versio, mikäli graphichsmagick onnistuu asentaa!!

def generateThumbnail(filename, path)
  
  # last char must be '/' or if path is  empty
  if path.empty? or path[path.length - 1].chr != '/'
    path = path + '/'
  end
  
  if File.exist?("." + path + filename)
    
    contenttype = MIME::Types.type_for(filename).to_s
    
    begin

      img = Magick::Image.read('.' + path + filename).first
      thumb = img.scale(0.25)
 
      if contenttype == "application/pdf"
        filename = filename.gsub(/.pdf/, ".png")
      end
      name = path + filename
      thumb.write '.' + name + ".thumbnail.temp"

      return name
      
    rescue => exception
      begin
        thumb = Magick::Image.read("./.visualrest_unknown.png").first
        name = path + filename
        thumb.write '.' + name + ".thumbnail.temp"
        return name
      rescue => exception
        puts "Thumbnail creation failed!"
        puts exception 
      end
    end
    
  else
    puts "File not found!"
  end
  
end
=end

# Creates and uploads thumbnail of an object
# params: plain file name, plain file path
def createAndUploadThumbnail(filepath, commit_id = false)
  blob = @@gitusage.getBlobByFilepath(filepath, commit_id)
  if blob
    temp = generateThumbnail(blob)
    uploadfile(filepath, commit_id, temp)
    begin
      File.delete('./'+temp)
    rescue => exception
      puts "Temp file deletion failed!"
      puts temp
      puts exception
    end
  end
end



def generateThumbnails(commit_id = false)
  con = ""
  if commit_id
    con = @@gitusage.getChangesOfCommit(commit_id)
  else
    con = @@gitusage.getFilelistOfCommit(false)
  end
  c = con.length
  puts "\nGenerating #{c.to_s} thumbnails..."
  pbar = ProgressBar.new("Thumbnails", c)
  con.each do |filepath, metadata|
    if commit_id == false or metadata['status'] != 'deleted'
      createAndUploadThumbnail(filepath, commit_id)
      pbar.inc
    end
  end
  
  pbar.finish
  puts "Thumbnails generated!"
  
  
end


def generateThumbnailsOfBlobs(blob_ids, commit_id)
  # get filelist of commit
  filelist = @@gitusage.getFilelistOfCommit(commit_id, true)
  if filelist
    # create and upload thumbnail for each blob
    blob_ids.each do |blob_id|
      b = filelist[blob_id]
      if b
        filepath = b["path"] + b["name"]
        createAndUploadThumbnail(filepath, commit_id)
      end
    end
  end
end



def uploadfile(filepath, commit_id = false, thumbnail = false)
  blob = @@gitusage.getBlobByFilepath(filepath[1..-1], commit_id)
  if (not thumbnail and blob) or File.exist?("./" + thumbnail)
    begin
      # Send file
      multipart = (thumbnail == false ? Multipart.new( "." + filepath) : Multipart.new( "./" + thumbnail))
            
      address =  @@host + "/user/" + @@conf["username"] + "/device/" + @@conf["dev_name"] + "/files" + filepath
      
      if not thumbnail
        
        @@status.merge!({'uploading_file' => filepath})
        @@status.merge!({'uploading_file_hash' => blob.id})
        online
        
        puts "Uploading file..."
        multipart.put(address, filepath, StringIO.new(blob.data), blob.size, blob.id, false)
        
        @@status.delete_if {|key, value| key == "uploading_file" }
        @@status.delete_if {|key, value| key == "uploading_file_hash" }
        online
      
      else
        multipart.put(address, filepath, false, false, blob.id, true)
      end

    rescue => exception
      puts exception
      puts "Uploading failed!"    
    end
    if not thumbnail
      puts "File uploaded!"
    end
  else
    puts "File " + "." + filepath + " not found!"
  end
  
end




def submitFilelist(commit_id = nil)
  
  begin
    puts "Sending filelist..."
    
    path = '/user/' + @@conf["username"] + '/device/' + @@conf["dev_name"] + '/files'
    my_commit = (commit_id != nil ? commit_id : @@gitusage.getOldestUnreportedCommit)
    if my_commit == false
      my_commit = @@gitusage.getNewestCommit
    end
    filelist = (my_commit != false ? @@gitusage.getChangesOfCommit(my_commit) : false)
    if filelist == false
      puts "filelist not sent"
      return
    end
    contains = YAML.dump_stream(filelist)
    commit_location = YAML.dump_stream(@@gitusage.getCommitLocation(my_commit))
    puts commit_location
    
    # The data we're going to be sending:
    params = { 'contains' => contains, 'commit_hash' => my_commit, 'commit_location' => commit_location}

    parent = @@gitusage.getParentOfCommit(my_commit)
    if parent == false
      puts "error in submitFilelist"
      return
    elsif parent != nil
      params['prev_commit_hash'] =  parent
    end

    res = nil
    i = 0
    while i < 3 do
      begin
        res = HttpRequest.new(:put, path, params).send(@@host)
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
      raise Exception.new("Can't establish connection to visualrest server!")
    end
    if res.code.to_s != "202" and res.code.to_s != "401"
      raise Exception.new("Serverside error")
    elsif res.code.to_s == "401"
      puts "Filelist not accepted"
      puts res.body
    elsif res.code.to_s == "202"
      puts "filelist sent ok!"
      @@waiting_for_parse_confirmation = true
    end
  rescue => exception
    puts exception
    puts "Filelist sending failed!"
    return
  end
end





def activeChecking(time)
  @@t = Thread.new{

    sleep(@@threadSleep)
    
    while true
      begin
        sleep(time)
        
        @@gitusage.addNewFilesToRepo
        # if changes to filelist or unsubmitted filelists present
  
        if (@@gitusage.commitChanges(@@location.getLocation) or @@gitusage.getOldestUnreportedCommit) and not @@waiting_for_parse_confirmation
          if @@test_messages
            puts "Files were changed and needs to be updated to the server"
          end
        
          submitFilelist
          
          sleep(20)
        else
          if @@test_messages
            puts "No changes in filelist"
          end 
        end 
      rescue => e
        puts "Errors in active checking: " + e
      end
    end
  }

  @@threadIDs.merge!({@@t.to_s => "active checking"})

end


# Reports that device is online
def reportOnline(time)
  t =Thread.new{
    puts "Online report thread = " + Thread.current.to_s
    sleep(@@threadSleep)
    while true
      sleep(time)
      online
    end
  }
  
    if @@test_messages
    puts "Online report thread = " + t.to_s
  end
  @@threadIDs.merge!({t.to_s => "online report"})
end





# makes request to the url and returns the response
def openUrl(url)
  i = 0
  data = nil
  while i < 3 do
    begin
      data = open(url).read
      i = 3
    rescue
      sleep(1)
      i += 1
    end
  end
  return data
end




def checkOpts
  @@self_port = @@opts[:port]
  puts "Self port: " + @@self_port.to_s
  
  if(@@opts[:host].index("http://") == 0 or @@opts[:host].index("https://") == 0)
    @@host = @@opts[:host].to_s
  else
    @@host = "http://" + @@opts[:host].to_s
  end
  
  # Deletes the last slash from the end of the given host name, if slash is given
  if @@host.rindex('/') == @@host.size - 1
    @@host = @@host[0, @@host.size - 1]
  end
  
  

  if @@opts[:mode].to_s == "nikkis"
    @@host = "http://" + @@nikkis_ip + ":3001"
  end
  
  puts "Host: " + @@host
  
  if @@opts[:active_check] != 0
    # If the active checking time was given
    puts "Active checking every " + @@opts[:active_check].to_s + " seconds"
    if @@opts[:active_check].to_i
      activeChecking(@@opts[:active_check])
    end
  end
  
  if @@opts[:online_report] != 0
    reportOnline(@@opts[:online_report])
  end
  
  
  if @@opts[:test_messages]
    @@test_messages = true
    puts "Prints test messages"
  end
  
  
end







# Main #############################################################




if File.exist?("device_identity") 
  if @@conf == nil
    puts "Unable to open device_identity file!"
  end
  
  # check if options were given
  checkOpts
  
  # create jabber connection
  runJabber
  
  # Starts fileserver
  runFileServer
  
  data = online.body
  
  puts("the received data is: #{data}")
  puts "the session_id cookie is: #{@@cookie.to_s}"
  
  
  if data == "Invalid username or password" or data == "0"
    exit
  end
  
  @@gitusage.addNewFilesToRepo
  # if changes to filelist or unsubmitted filelists present
  if (@@gitusage.commitChanges(@@location.getLocation) or @@gitusage.getOldestUnreportedCommit) and not @@waiting_for_parse_confirmation
    submitFilelist
  end
  
  print "\n", "Press enter to give commands!", "\n"
  
  
  
else
  dev_type = "#{RUBY_PLATFORM}___#{ENV['OS']}"
  #puts dev_type
  #dev_type = "mac"
  # dev name pitisi varmaan tulla serverilt jossa kyttj ptt (dev_name)
  # laitteen tyypin (dev_type), kyttjnimen (username) ja salasanan (password)
  puts "Welcome to use VisualREST in this device." 
  
  print "Enter your user name: " 
  username = STDIN.gets
  print "Enter your password: " 
  password = STDIN.gets   
  print "Enter name for the device: " 
  dev_name = STDIN.gets
  print "\n"
  
  checkOpts
  
  # vanhin:  url =  "http://nota.cs.tut.fi:8080/device/register?username=#{username}&password=#{password}&dev_name=#{dev_name}&dev_type=#{dev_type}"                             
  # EI REST: url =  @@host + "/device/register?username=#{username}&password=#{password}&devicename=#{dev_name}&dev_type=#{dev_type}"                             
  # REST:
  path = "/user/#{username.strip}/device/#{dev_name.strip}/"
  puts path
  path.gsub!(/[\n\r]/, "")
  path.strip

  # EI REST: data = open(url).read
  # REST:
  params = {"password" => password.strip, "dev_type" => dev_type.strip}
  res = HttpRequest.new(:put, path, params).send(@@host)
  puts "CODE: " + res.code
  
  print "\n"
  puts("the received data is: #{data}")
  #if data == "Invalid username or password" or data == "0"
  if res.code != "201"
    exit
  end
  
  print "Press enter to give commands!", "\n"
  #  aFile = File.new("device_identity", "w+")
  #  if aFile
  #    aFile.syswrite("#{data}")
  #    aFile.syswrite("\n" + username)
  #    aFile.syswrite(password)
  #    aFile.syswrite(dev_name)
  #  
  # Saves the device identity and jabber account
  begin
    puts "writing hash file..."
    
    jabber_account = username.strip() + "_" + dev_name.strip() + "@" + @@xmpp_host
    device_hash = {"username" => username.strip, "password" => password.strip, "dev_name" => dev_name.strip, "jabber_account" => jabber_account}
    
    File.open("device_identity", "w+"){|f|
      YAML.dump(device_hash, f)
    }
    @@conf = YAML::load File.new('device_identity')
  rescue
    puts "unable to write hashfile!"
  end
  
  
  # create jabber connection
  runJabber
  
  # Starts fileserver
  runFileServer
  
  
  
  
end



cmdLine
while line = STDIN.gets
  cmd, arg = line.strip.split(/ /, 2)
  command("", cmd, arg) if cmd != nil && !cmd.empty?
  cmdLine
  
end

puts "loppu"


Thread.stop
puts "................."
 
