class DropboxWorker < BackgrounDRb::MetaWorker
  
  set_worker_name :dropbox_worker
  
  
  
  def create(args = nil)
    
    
    # this method is called, when worker is loaded for the first time

    @poll_interval = 15

    @@semaphore = Mutex.new

    @@polling_on_progress = Array.new(1,false)
    
    
    
    runDBDirPoller
    add_periodic_timer(@poll_interval) { runDBDirPoller }
    
  end
  
  
  
  
  
  
  def runDBDirPoller
    
    
    dirs2poll = UserDropboxContent.find(:all, :conditions => ["parent_dir_id is NULL and content_type = 'root'"], :order => "user_id")
    @@semaphore.synchronize{
      # This prevents polling simultaneously if
      if @@polling_on_progress.include?(true)
        puts "----------------------------kaynnissa---------------------------------------"
        #puts @@polling_on_progress.to_s
        putsRunning
        return
      else
        
        # Removes unwanted folders and files
        sql = "SELECT * 
               FROM user_dropbox_contents
               WHERE content_type != 'root'"
        udcs = UserDropboxContent.find_by_sql(sql)
        udcs.to_s
        udcs.each do |udc|
          checkAndCleanForRootDir(udc)
        end
        
        puts "#########################################################"
        puts "#       POLLING DROPBOX FOLDERS                         #"
        puts "#########################################################"
        
        puts "Poll interval: #{@poll_interval.to_s}"
        
        puts "----------------------------asetetaan kayntiin------------------------------"
        #puts @@polling_on_progress.to_s
        putsRunning
        @@polling_on_progress = Array.new(dirs2poll.count,true)
      end
    }
    
    i = 0
    
    user = nil
    si = nil
    dirs2poll.each do |dir|
      
      dirNum = i  
      i += 1
      
      Thread.new{
        
        begin
               
          if not user or user.id != dir.user_id 
            user = dir.user
            si = ServiceInformation.find(:first, :conditions => ["user_id = ? and service_type = ?", user.id, "dropbox"])
          end
          
          
                
          if not user or not si
            @@polling_on_progress[dirNum] = false
            puts "User or service information not found for dir => skipping..."
            next
          end
          
          device = Device.find_by_id(dir.device_id)
          if not device 
            @@polling_on_progress[dirNum] = false
            # if device has been removed, removes also the root dir
            dir.delete
            puts "Device not found for dir => skipping..."
            next
          end
          
          vM = VirtualContainerManager.new(user, device.dev_name) 
          if not vM
            @@polling_on_progress[dirNum] = false
            puts "Virtual container not found for dir => skipping..."
            next
          end
          
          
          # Fetches the folder to poll and recursively all its subfolders. The subfolders are added also to folders to poll list
          
          
          dropbox_host = @@dropbox_host
          db_app_id = @@db_app_id
          db_app_secret = @@db_app_secret
          
          
          @dbHelp = DropboxHelper.new(user)          
          
          
          recUpdateDBFolders(user, device, vM, dir.path, dir.id, nil)
          vM.commit
          puts "VirtualContainer: #{vM.getDeviceObject.dev_name} Committed!".background(:green)
        rescue Exception => e
          putsE(e)
        end
        
        @@semaphore.synchronize{
          putsRunning
          #puts @@polling_on_progress.to_s
          @@polling_on_progress[dirNum] = false
          if not @@polling_on_progress.include?(true)
            puts "----------------------------pois kaynnista----------------------------------"
          end
          putsRunning
          #puts @@polling_on_progress.to_s
        }
      }
      
    end # loop

    return
  end
  
  
  
  
  
  
  
  
  
  private


  def recUpdateDBFolders(user, device, vM, db_dir, root_dir_id, vr_parent_dir_id = nil)

    

    mdata = @dbHelp.getMetadatas(db_dir)
    
    if mdata and not mdata["error"] and mdata["is_dir"]
            
      
      vr_dir = UserDropboxContent.find_or_create_by_user_id_and_device_id_and_path_and_parent_dir_id_and_root_dir_id(user.id,
                                                                                           device.id,
                                                                                           db_dir,
                                                                                           vr_parent_dir_id,
                                                                                           root_dir_id)
      if not vr_dir.content_type and mdata["is_dir"]
        vr_dir.update_attribute(:content_type, "folder")
      elsif not vr_dir.content_type and not mdata["is_dir"]
        vr_dir.update_attribute(:content_type, "file")
      end


      existing_content = []
      
      if vr_dir.content_hash == nil or vr_dir.content_hash != mdata["hash"]
        
        
        
        if mdata["contents"] and vr_dir.content_hash == nil or vr_dir.content_hash != mdata["hash"]
          mdata["contents"].each do |cont|  
            existing_content << cont["path"]
            if not cont["is_dir"]        
              
              
              # The content of the dir
              #if not checkAndCleanForRootDir(root_dir_id) then return end
              vr_cont = UserDropboxContent.find_or_create_by_user_id_and_device_id_and_path_and_parent_dir_id_and_content_type_and_root_dir_id(vr_dir.user_id,
                                                                                           vr_dir.device_id,
                                                                                           cont["path"],
                                                                                           vr_dir.id,
                                                                                           "file",
                                                                                           root_dir_id)
              s = cont["path"].to_s + cont["modified"]
          
              sha1 = Digest::SHA1.hexdigest(s)
              
              if vr_cont.content_hash != sha1
                puts "File : #{cont["path"]} needs to be downloaded (#{device.dev_name.to_s}) because its hash has changed!"
                puts "...Downloading"
                begin
                  essence = @dbHelp.downloadFile(vr_cont.path)
                  puts "...Downloading finsihed!"  
                  
                  vr_cont.update_attribute(:content_hash, sha1)
                  
                  vM.addFile(vr_cont.path, essence)
                  vM.addMetadata(vr_cont.path, "origin", "dropbox")
                rescue Exception => dex
                  puts "Downloading failed!"
                  puts dex.to_s
                end
              end
              
            end
          end
        end
        
        
        # If the content was folder, deletes the files (from db and from vc folder) that are not in
        # the dropbox folder anymore
        
        
        
        # Fetches files and dirs that are inside the current dir
        vr_db_folder_content = UserDropboxContent.find(:all, :conditions => ["root_dir_id = #{root_dir_id} and content_type != 'root' and user_id = #{vr_dir.user_id} and parent_dir_id = #{vr_dir.id} and device_id = #{vr_dir.device_id} and path like ?", "#{vr_dir.path}/%"])
        
        # Deletes that dropbox content that should not exist anymore
        vr_db_folder_content.each do |vr_db_cont| 
          #puts "vr_db_cont #{vr_db_cont.path}".background(:blue)
          if not existing_content.include?(vr_db_cont.path)
            puts "..Poistetaan #{vr_db_cont.path}!".background(:red)
            
            filename = vr_db_cont.path
            path = filename.match(/^.+\//).to_s
            name = filename.gsub(path,'').to_s
            
            puts "path: #{path}   name: #{name}"
            
            sql = "SELECT devfiles.* 
                  FROM devfiles, devices 
                  WHERE devices.user_id = '#{vr_db_cont.user_id.to_s}' AND 
                        devices.id = devfiles.device_id AND
                        devfiles.path = '#{path.to_s}' AND devfiles.name = '#{name.to_s}'"
            dfs = Devfile.find_by_sql(sql)
            
            dfs.each do |df|
              puts "Deleting df: #{df.name} id: #{df.id.to_s}"
              df.update_attribute(:deleted, true)
            end
             
            
            vr_db_cont.delete
          end
        end
      end
        
      vr_dir.update_attribute(:content_hash, mdata["hash"])
      
      # Checks if the dir had sub-dirs
      if mdata["contents"]
        mdata["contents"].each do |cont|
          if cont["is_dir"]
            vM.commit
            recUpdateDBFolders(user, device, vM, cont["path"], root_dir_id, vr_dir.id)
          end
        end
      end
      
    else
      puts "Error or not dir => skipping.."
      return
    end
  end
  
  
  def checkAndCleanForRootDir(udc)
    if not UserDropboxContent.find_by_id(udc.root_dir_id)
      puts "cleaning: #{udc.path}"
      udc.delete
      return false
    else
      #puts "not cleaning"
      return true
    end
  end
  
  
  def putsRunning
    @@polling_on_progress.each do |tt|
      if tt
        print "run".to_s.background(:green)
      else
        print "stop".to_s.background(:red)
      end
    end
    print "\n"
  end

  
  
  
  
  def putsE(e)
      puts "DropBox Error: #{e.to_s}"
      puts "  -- line: #{e.backtrace[0].to_s}"
  end
  
  
  
end

