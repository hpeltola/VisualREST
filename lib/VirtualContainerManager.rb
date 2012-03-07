

class VirtualContainerManager
  
  #
  # Creates a new virtual container or uses an existing one
  #
  def initialize(user, containername, debugmode = false)
    begin
      
      @virtual_container = findOrCreateVirtualDevice(user.id, containername)
      @debugmode = debugmode
      @fileMetadata = Hash.new
      
      # Directory where .git repository is (or will be)
      @dev_path = "private/#{@virtual_container.id.to_s}/"



      # If git repository doesn't yet exist for this device, create it
      if not File.exists?("#{@dev_path}.git")
        # Create new repo
        @repo = Grit::Repo.init_bare("#{@dev_path}.git", {:bare => false})
        #@repo = Grit::Repo.init_bare("#{@dev_path}.git") # Nikon
      else
        # Repo already existed
        @repo = Grit::Repo.new("#{@dev_path}.git")
      end
      
      @git = Grit::Git.new("#{@dev_path}.git")
      
      if not @repo
        raise Exception.new("Error: could not initialize repo. Try with {:bare => false} ")
      end
      
    rescue Exception => e
      putsE(e)
      raise Exception.new("Could not create a new virtual container!")
    end
  end
  
  
  #
  # Adds a file but NO commit!
  #
  def addFile(filename, essence)
    
    
    
    begin
     

      filesize = essence.length
      filename.gsub!(/ /, '_')
      
      # if filesize is larger than about 5mb, increase git timeout
      if filesize > 5000000
        Grit::Git.git_timeout = 30
        # if filesize is larger than about 100mb, throw an exception
        if filesize > 100000000
          raise Exception.new("File is too large to handle with git")
        end
      else
        Grit::Git.git_timeout = 10
      end
     
      # create dir if it does not exist
      if not (File.exists?(@dev_path) && File.directory?(@dev_path))
        FileUtils.mkdir_p(@dev_path)      
      end
      
      
      if filename.size > 1
          path = filename[0..filename.rindex('/')]
          FileUtils.mkdir_p(@dev_path+path)      
      end
      
      #puts "name: #{filename}"
      #puts "path: #{path}"
      
      
      path = File.join(@dev_path, filename)
      # write the file
      File.open(path, "wb") { |f|   
        #puts f.to_s
        f.write(essence)
        
      }
      sleep(0.2)
      @repo.add("#{@dev_path}#{filename}")
      puts "File " + filename + " added to repo."
    rescue Exception => e
      puts "Error: #{e.to_s}"
      puts "  -- line: #{e.backtrace[0].to_s}"
      raise Exception.new("Could not add a new file to virtual container!")
    end
    return true
  end
  
  #
  # Adds metadata to a file. After commit the metadata will be added to the file
  # 
  def addMetadata(filename, metadatatype, metadatavalue)
    begin
      
      if @fileMetadata.has_key?(filename)
        @fileMetadata[filename] = @fileMetadata[filename].to_s + "&&&" + metadatatype.downcase + ":" + metadatavalue.downcase
      else
        @fileMetadata[filename] = metadatatype.downcase + ":" + metadatavalue.downcase
      end
      
    rescue Exception => e
      puts "Error: #{e.to_s}"
      puts "  -- line: #{e.backtrace[0].to_s}"
      raise Exception.new("Could not add metadata to a new file!")
    end
  end
  
  def commit
    begin
      @repo.commit_all("commit of a virtual container")
      
  
      commitManager = CommitManager.new(@virtual_container, false, false)


      prev_commit = Commit.find_by_id(@virtual_container.commit_id)  
      if prev_commit
        prev_commit_hash = prev_commit.commit_hash
      else
        prev_commit_hash = nil
      end
      
      if @repo.commits.first == nil
        puts "Repository was empty?".background(:red)
        @repo = Grit::Repo.init_bare("#{@dev_path}.git")
        @git = Grit::Git.new("#{@dev_path}.git")
        #return false
        @repo.commit_all("commit of a virtual container")
      end
      
      commit_hash = @repo.commits.first.id
      
      #commit = @virtual_container.commits.find_or_create_by_previous_commit_id_and_commit_hash(:previous_commit_id => @virtual_container.commit_id,
      #                                  :commit_hash => commit_hash)
      
      filelist = getChangesOfCommit(commit_hash) #getFilelistOfCommit(commit_hash)
      
      
            
      if commitManager.updateFilelist(filelist, commit_hash, prev_commit_hash)
        puts "Filelist updated successfully..".background(:green)
        genetrateThumbs(commit_hash, filelist)
        puts "Thumbnails generated successfully..".background(:green)
        
        begin
          # Add metadata to the files
          @fileMetadata.each{ |filename, metadatas|
            
            path = filename.match(/^.+\//).to_s
            name = filename.gsub(path,'')
            

            if name[0,1] == '/'
              name = name[1..-1]
              path = '/'
            end

             devfile = Devfile.find_by_device_id_and_name_and_path(@virtual_container.id, name, path)
             if devfile == nil
               puts "Couldn't find devfile while adding metadata"
               next
             end
              metadatas.split('&&&').each{ |datas|
                index = datas.index(':')
                mtype = datas[0..index-1]
                mvalue = datas[index+1..-1]
                
                #puts "Add metadata type: #{mtype}   value: #{mvalue}"
                
                if mtype == "description"
                  devfile.update_attribute(:description, mvalue)
                else
                  type = MetadataType.find_by_name(mtype)
                  if type != nil
                    Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(mvalue, nil, devfile.id, type.id)
                  else
                    puts "Couldn't add metadata: #{mvalue}, because metadatatype: #{mtype} was not found"
                  end
                end
              }
          }
          
          begin
            filelist.each do |x|
              deletepath = x[0][1..-1]
              if File.exists?(deletepath)
                FileUtils.rm_f(deletepath)
                puts "deleted the essence that is still stored in git.."
              else
                puts "Essence not found..."
              end
            end
          rescue => e
            puts "Error deleting essence: #{e}"
          end
          
        rescue => e
          puts "Failed to add metadata to file: #{e}"
        end
        return true
      else
        #puts "Failed to update filelist!".background(:red)
        return false
      end
      
      
    rescue Exception => e
      if e.to_s != "Error: Commit already in database"
        puts "Error: #{e.to_s}"
        puts "  -- line: #{e.backtrace[0].to_s}"
        raise Exception.new("Could not commit files of the virtual container!")
      end
    end
  end
  
  
  
  def getDeviceObject
    return @virtual_container
  end
  
  
  
  private
  
  
  
  
  def genetrateThumbs(commit_hash, filelist)
    
    begin
      commit = Commit.find(:first, :conditions => ["commit_hash = ? and device_id = ? ", commit_hash, @virtual_container.id])
      
      filelist.each do |key, f|

        devf = commit.device.devfiles.find_by_name_and_path(f["name"], f["path"])

        blob = commit.blobs.find(:first, :conditions => ["id = ?", devf.blob_id])
#puts "...Generating thumbnail for: #{blob.devfile.name.to_s}, type: #{blob.devfile.filetype.to_s}, container: #{@virtual_container.dev_name}"
        thumb_name = createThumbnail(blob, f["filetype"], @virtual_container )
#puts "...VALMIS.... Generating thumbnail for: #{blob.devfile.name.to_s}, type: #{blob.devfile.filetype.to_s}"
        #blob.update_attribute(:thumbnail_name, thumb_name)
      end
    rescue Exception => e
      putsE(e)
    end
    
  end
  
  
  
  
  
  #
  # Generates a thumbnail for a blob
  #
  def createThumbnail(blob, contenttype, device )


    thumb_path = "public/thumbnails/#{device.id}/"
    
    thumb_name = blob.blob_hash.to_s+".png"

    if contenttype == "image/jpeg" or contenttype == "image/png" or contenttype == "image/gif"
        data = getBlobById(blob.blob_hash)
        createIcon(data, thumb_name, thumb_path)
        blob.update_attribute(:thumbnail_name, thumb_name)
        return thumb_name
        
    elsif contenttype == "video/x-msvideo" or contenttype == "video/msvideo"
      format = blob.devfile.name.split(".").last
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
      puts "Unknown Filetype: #{contenttype.to_s}".background(:red)
      vR_default_thumbnail_file = "vR_unknown.png"
    end
    
    # create dir if it does not exist
    if not (File.exists?(thumb_path) && File.directory?(thumb_path))
      FileUtils.mkdir_p(thumb_path)
    end
      
    # Copy default thumbnail to file
    from = "public/thumbnails/vR_default_thumbnails/" + vR_default_thumbnail_file
    to = thumb_path+thumb_name
    # ftools (ruby 1.8.7)
    #File.copy(from, to )
    
    # fileutils (ruby 1.9.2)
    FileUtils.cp(from, to )
    
    
    blob.update_attribute(:thumbnail_name, thumb_name)
    return thumb_name
  end # createThumbnail end
  
  
  
  
  
  
  
  #
  #   Creates and scales icon from given data and saves it as given name
  #
  def createIcon(data, icon_name, icon_path)
  
  
    begin
      icon_data = data
      
      # Scaling the icon
      img = Image.from_blob(icon_data).first
      icon = scale(img)

       # create dir if it does not exist
      if not (File.exists?(icon_path) && File.directory?(icon_path))
        FileUtils.mkdir_p(icon_path)
      end

      # create the file path
      full_path = File.join(icon_path, icon_name)
  
      icon.write("png:"+ full_path)

    rescue Exception => e
      putsE(e)
      return false
    end

    return true
  end # createIcon end


  def scale(i)
    i.change_geometry!('128x128') { |cols, rows, img|
      img.resize!(cols, rows)
    }
    
    return i
  end # scale end
  
  
  # returns data of the blob with given id
  def getBlobById(blob_id)
    b = @repo.blob(blob_id).data
    if b == ""
      # either the blob doesn't exist or it does but the data is empty
      return false
    end
    return b
  end
  
  
  
  
  
  
  
  
  # returns a hash containing only changed files (created, updated or deleted)
  # of the commit with given id. if no id given, uses the newest commit.
  def getChangesOfCommit(commit_id = false)
    my_commit = ((commit_id == false and @repo.commits.size > 0) ? @repo.commits.first : @repo.commit(commit_id))
    if my_commit == nil
      return false
    end
    
    # get list of changed files and parse it
    @filelist = Hash.new
    options = {:r => true, :name_status => true, :no_commit_id => true}
    if @repo.commit(my_commit.sha).parents[0] == nil # if my_commit is the first commit
      options[:root] = true
    end
    changed_files_list = @git.diff_tree(options, my_commit.id).strip
    if changed_files_list.class == String and changed_files_list.length > 0
      changed_files_list.split("\n").each do |f|
        commit = my_commit
        operation = f[0,1] # D/M/A
        filepath = f[2..-1] # path+filename
        path = "/" + filepath.match(/^.+\//).to_s # just path
        status = "created"
        if operation =~ /^D$/i # deleted
          # the file was deleted, so get the blob from the parent-commit
          commit = @repo.commit(my_commit.parents[0].sha)
          status = "deleted"
        elsif operation =~ /^M$/i # modified
          status = "updated"
        end
        blob = commit.tree/(filepath)

        #name = filepath.gsub(path[1..-1], '') #blob.name
        path = path.gsub(/\/private\/[0-9]+\//,'')
        
        
        
        @filelist["/" + filepath] = {"uploaded" => '1', "status" => status, "blob_hash" => blob.id, "name" => blob.name, "path" => "/#{path}", "size" => blob.size, "filetype" => blob.mime_type, "filedate" => @repo.commit(commit.sha).date.strftime('%T %F').to_s}
        
      
      end
    end

    if @filelist.size > 0
      return @filelist
    else
      return false
    end
  end
  
  
  
  
  
  
  
  
  
  
  
  
  
=begin
  
  # returns a hash representing the full filelist of the commit with given id.
  # if no id given, returns filelist-hash of the newest commit.
  # if blob_id_as_key = true, returned hash will have blob-id-hash as key instead of filepath
  def getFilelistOfCommit(commit_id = false, blob_id_as_key = false)
    begin
      my_commit = (commit_id == false ? @repo.commits.first : @repo.commit(commit_id))
      if my_commit == nil
        return false
      end
    
      # iterate through filelist of the commit
      @filelist = Hash.new
      fillFilelistFromTree(my_commit.tree, "/", my_commit.date.strftime('%T %F').to_s, blob_id_as_key)
      return @filelist
      rescue => e
        puts e
      end
  end
  
  
  #
  # NOTE!!!
  # Remenber to create and make sure that @filelist is allways empty before calling this method!!!
  # => @filelist = {}
  def fillFilelistFromTree(tree, path, date, blob_id_as_key = false)
    tree.contents.each do |c|
      if c.class == Grit::Blob
        if blob_id_as_key
          @filelist[c.id] = {"blob_hash" => c.id, "name" => c.name, "path" => '/', "filetype" => c.mime_type, "size" => c.size, "filedate" => date}
        else
          @filelist[path + c.name] = {"blob_hash" => c.id, "name" => c.name, "path" => '/', "filetype" => c.mime_type, "size" => c.size, "filedate" => date}
        end
      elsif c.class == Grit::Tree
        fillFilelistFromTree(c, path + c.name + "/", date, blob_id_as_key)
      end
    end
  end
=end
  
  
  
    def putsE(e)
        puts "Error: #{e.to_s}".background(:blue)
        puts "  -- line: #{e.backtrace[0].to_s}"
    end
  
  
  
  
  
  
  def findOrCreateVirtualDevice(user_id, dev_name)
    device = Device.find_by_user_id_and_dev_name(user_id, dev_name)
    if device != nil
      if device.dev_type != "virtual_container"
        # Device with right name and wrong type was found
        return nil      
      end
    else
      # Device with requested name wasn't found, lets create it
      device = Device.create(:user_id => user_id,
                             :dev_name => dev_name,
                             :dev_type => "virtual_container",
                             :last_seen => DateTime.now,
                             :direct_access => false)
    end
    return device
  end
  
  
end