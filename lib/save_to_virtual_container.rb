# This class is used for saving file to virtual container.
# The file will be saved to the virtual container's git repository.

require 'grit'

class SaveToVirtualContainer
  
  # getter and setter
  attr_reader :devfile, :devfile_id
  
  # Parameters:
  #   - dev_id   (id of the virtual container)
  #   - filename (name of the file that will be saved)
  #   - upload   (the file-data)
  def initialize(dev_id, filename, upload)
    if dev_id == nil or filename == nil or upload == nil
      puts "SaveToVirtualContainer: Not all parameters given."
      return
    end

    device = Device.find_by_id(dev_id)
    if device == nil or device.dev_type != "virtual_container"
      puts "SaveToVirtualContainer: virtual_container couldn't be found.'"
      return
    end
    
    
    
    # Directory where .git repository is (or will be)
    dev_path = "private/#{dev_id}/"
   
    # create dir if it does not exist
    if not (File.exists?(dev_path) && File.directory?(dev_path))
      FileUtils.mkdir_p(dev_path)      
    end    
    
    # If devfile with same name on same device exist, make new blob for the devfile
    prev_devfile = Devfile.find_by_name_and_path_and_device_id( filename, '/', dev_id)
    
    savePath = filename
    
    if prev_devfile != nil
      old_version = Blob.find_by_id(prev_devfile.blob_id).version.to_i + 1 
      savePath += old_version.to_s
    end
    
    path = File.join(dev_path, savePath)
    # write the file
    File.open(path, "wb") { |f|   
      puts f.to_s
      f.write(upload)
    }
    puts "completepath: " + dev_path
    puts "File " + savePath + " created."


    
    # Add the new file to git and create blob
    @devf = addToGitAndCreateBlob(device, dev_path, filename, prev_devfile, savePath)
    @devf_id = @devf.id
    
    # Delete the file, since it is added to git
    #File.delete(path)    

    return
  end # save end
  
  def addMetadata(metadatatype, metadatavalue)
    if metadatatype == nil or metadatavalue == nil or @devf_id == nil
      return false
    end
    
    type = MetadataType.find_by_name(metadatatype)
    if type == nil
      return false
    end
    
    Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(metadatavalue, nil, @devf_id, type.id)
    return true
  end
  
  def addToContext(contextID, metadatatype, metadatavalue)
    if metadatatype != "context_hash" or metadatavalue == nil or @devf_id == nil
      return
    end
    
    type = MetadataType.find_by_name(metadatatype)
    if type == nil
      return
    end
    
    Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(metadatavalue, nil, @devf_id, type.id)
    
    # Adds same group rights to the devfile as context has
    groups = ContextGroupPermission.find_all_by_context_id(contextID)
          
    if groups
      groups.each do |cgp|
        DevfileAuthGroup.find_or_create_by_devfile_id_and_group_id(:devfile_id => @devf_id,
                                                                   :group_id => cgp.group_id)
      end
    end
    
    return
  end
  
  
  def getDevfile
    return @devf
  end
  
  
  #########
  private # all methods that follow will be made private: not accessible for outside objects
  #########
  
  
  def addToGitAndCreateBlob(device, dev_path, filename, prev_devfile, savePath)
    
    # If git repository doesn't yet exist for this device, create it
    if not File.exists?("#{dev_path}.git")
      # Create new repo
      repo = Grit::Repo.init_bare("#{dev_path}.git")
    else
      # Repo already existed
      repo = Grit::Repo.new("#{dev_path}.git")
    end
    
    puts "XOXOXO: " + "#{dev_path}#{savePath}"
    
    # Add file to repo and make a commit
    repo.add("#{dev_path}#{savePath}")    
    repo.commit_all("new commit")

    if repo.commits.first == nil
      puts "Repository was empty?".background(:red)
      repo = Grit::Repo.init_bare("#{dev_path}.git", {:bare => false})
#      @repo = Grit::Repo.init_bare("#{@dev_path}.git", {:bare => false})
    #  @git = Grit::Git.new("#{@dev_path}.git")
      #return false
          # Add file to repo and make a commit
      repo.add("#{dev_path}#{filename}")    
      repo.commit_all("new commit")
    end

    commit_hash = repo.commits.first.id
    commited_blob = repo.commits.first.tree.contents.first.contents.first.contents.last
    
    
    # Check type of file
    contenttype = "unknown"  
    if not MIME::Types.type_for(filename).to_s.empty?
        contenttype = MIME::Types.type_for(filename).to_s
    end
    
    # Create thumbnail
    thumbnail_name = createThumbnail(commited_blob, contenttype, device)
    
    
    # Add blob to database
    blob = Blob.create(:size => commited_blob.size,
                       :filedate => DateTime.now,
                       :uploaded => 1,
                       :version => 0,
                       :blob_hash => commited_blob.id,
                       :thumbnail_name => thumbnail_name)
           
    if blob == nil
      raise Exception.new("Problem creating blob")
    end       
           
    # This is used for making sure old blob won't end up in blobs_in_commit table
    old_blob = nil
           
    # If first version of file, create devfile
    if prev_devfile == nil     
      # Add devfile to database
      devfile = Devfile.create(:device_id => device.id,
                               :name => filename,
                               :path => '/',
                               :filetype => contenttype,
                               :privatefile => 1,
                               :blob_id => blob.id)
    # If adding new version of file, update link to new blob
    else
      old_blob_id = prev_devfile.blob_id
      
      # Update version number of blob
      old_blob = Blob.find_by_id(old_blob_id)
      old_blob.follower_id = blob.id
      old_blob.save
      blob.version = old_blob.version.to_i+1
      blob.predecessor_id = old_blob_id
      blob.save
      
      # Update old devfile
      devfile = prev_devfile
      devfile.blob_id = blob.id
      devfile.save
    end
              
    if devfile == nil
      raise Exception.new("Problem creating devfile")
    end


    @devf_id = devfile.id
                  
    # Tell blob which devfile it belongs to 
    blob.devfile_id = devfile.id
    blob.save
    
    previous_commit = device.commit_id
                   
    # Create commit
    commit = Commit.create(:device_id => device.id,
                           :commit_hash => commit_hash,
                           :previous_commit_id => previous_commit)
    
    if commit == nil
      raise Exception.new("Problem creating commit")
    end

    # create new link between blob and commit
    blobInCommit = BlobsInCommit.create(:blob_id => blob.id,
                                        :commit_id => commit.id)

    if blobInCommit == nil
      raise Exception.new("Problem creating blob in commit")
    end
      
    # Link old blobs into new commit
    if previous_commit != nil    
      old_blobs = BlobsInCommit.find_all_by_commit_id(previous_commit)
      if old_blobs != nil
        old_blobs.each do |x|
          if x.blob_id != old_blob_id
            BlobsInCommit.find_or_create_by_blob_id_and_commit_id(x.blob_id, commit.id)
          end
        end
      end
    end
      
    # update device info
    device.update_attribute(:last_seen, DateTime.now)
    device.update_attribute(:commit_id, commit.id)
    return devfile
  end # addToGitAndCreateBlob end
  
  
  
  
  def createThumbnail(blob, contenttype, device )

    thumb_path = "public/thumbnails/#{device.id}/"
    
    thumb_name = blob.id.to_s+".png"

    if contenttype == "image/jpeg" or contenttype == "image/png" or contenttype == "image/gif"
        createIcon(blob.data, thumb_name, thumb_path)
        return thumb_name
        
    elsif contenttype == "video/x-msvideo"
      format = blob.name.split(".").last
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
    
     
    return thumb_name
  end # createThumbnail end
  
  # Creates and scales icon from given data and saves it as given name
  def createIcon(data, icon_name, icon_path)
    
    begin
      icon_data = data
      
      # Scaling the icon
      img = Image.load(icon_data)
      icon = scale(img)
      
       # create dir if it does not exist
      if not (File.exists?(icon_path) && File.directory?(icon_path))
        FileUtils.mkdir_p(icon_path)
      end
      
      # create the file path
      full_path = File.join(icon_path, icon_name)
  
      icon.export(full_path)

    rescue Exception => e
      putsE(e)
      return false
    end
    
    return true
  end # createIcon end


  def scale(i)
    i.resize! 128, 128
    
    return i
  end # scale end
  
  
end # class end