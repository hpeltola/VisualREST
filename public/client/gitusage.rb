require 'rubygems'
require 'yaml'
require 'grit'

class GitUsage
  
  def initialize(location)
    begin
      # load metafile
      @@commits_metafile = ".commits_metafile"
      if File.exists?(@@commits_metafile)
        @commits = YAML::load File.new(@@commits_metafile)
      end
      
      @@vR_branches_metafile = ".vR_Branches_metafile"
      if File.exists?(@@vR_branches_metafile)
        @vR_branches = YAML::load File.new(@@vR_branches_metafile)
      else
        @vR_branches = {}
      end
      
      if @commits == nil or @commits == false
        @commits = Array.new
      end
      
# TODO: Täytyy tarkistaa gitin versio ja se löytyykö gittiä ylipäätään! mikäli käytetään sitä versiota joka on maemossa niin alustus tehdään @repo = Grit::Repo.init_bare(".git", {:bare => false})
      # create/get repository
      if not File.exists?(".git")
        #@repo = Grit::Repo.init_bare(".git", {:bare => false}) #maemo's git
        @repo = Grit::Repo.init_bare(".git") # pc's git
      else
        @repo = Grit::Repo.new(".git")
      end
      
      # create git-object
      @git = Grit::Git.new(".git")
      
      # make sure commits_metafile is updated
      updateCommitsMetafile
      
      # add new files and commit changes to git & metafile
      @uninclude_from_repo_entries = ["device_identity", "temp", "vR_default_thumbnails", "filelist.html", "client6.rb", "gitusage.rb", "fileservlet80.rb", "fileservlet30.rb", "upload.rb", "location.rb", "fileservletall.rb"]
      addNewFilesToRepo
      commitChanges(location)
    rescue => e
      puts "Error in init!"
      puts e
      return false
    end
  end
  
  
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
        @filelist["/" + filepath] = {"status" => status, "blob_hash" => blob.id, "name" => blob.name, "path" => path, "size" => blob.size, "filetype" => blob.mime_type, "filedate" => @repo.commit(commit.sha).date.strftime('%T %F').to_s}
        
        if @vR_branches[blob.id]
          @filelist["/" + filepath].merge!({"file_origin" => @vR_branches[blob.id]})
        end
      
      end
    end

    if @filelist.size > 0
      return @filelist
    else
      return false
    end
  end
  

  # adds new files to git, removes removed files from git, commits changes and updated commit_metafile  
  def commitChanges(location)
    newest_sha = (@repo.commits.size > 0 ? @repo.commits.first.sha : nil)
    @repo.commit_all("new commit")
    if @repo.commits.size > 0 and @repo.commits.first.sha != newest_sha
      addCommitToMetafile(@repo.commits.first.sha, false, location)
      return true
    end
    return false
  end
  
  
  # adds all new files to git-repo
  def addNewFilesToRepo(dir = ".")
    Dir.new(dir).each do |f|
      f_with_path = (dir != "." ? dir + "/" + f : f)
      next if f[0,1] == "." or @uninclude_from_repo_entries.include?(f_with_path)
      if FileTest.directory?(f_with_path)
        addNewFilesToRepo(f_with_path)
      elsif @repo.commits.size == 0 or @repo.commits.first.tree/("#{f_with_path}") == nil
        # if the file is new and hasn't been added to git-repo yet
        @repo.add(f_with_path)
      end  
    end
  end
  
  
  # returns data of the blob with given id
  def getBlobById(blob_id)
    b = @repo.blob(blob_id).data
    if b == ""
      # either the blob doesn't exist or it does but the data is empty
      return false
    end
    return b
  end
  
  
  
  # returns the blob corresponding to given filepath in the given commit.
  # uses newest commit if commit_id not given. If parameter justcheck=true, just
  # checks if the blob exists and returns boolean.
  def getBlobByFilepath(filepath, commit_id = false, justcheck = false)
    # get commit
    c = nil
    if commit_id == false
      c = @repo.commits.first
    else
      c = @repo.commit(commit_id)
    end
    if c == nil
      return false
    end
    
    if filepath[0,1] == "/"
      filepath = filepath[1..-1]
    end
    
    # get blob
    b = (c.tree/"#{filepath}")
    if b != nil and not justcheck
      return b
    elsif b != nil and justcheck
      return true
    else
      return false
    end
  end

  
  
  # returns id of the oldest commit that has NOT been reported to visualrest server.
  # returns false if all commits reported.
  def getOldestUnreportedCommit
    @commits.each do |c|
      if c[1] == false
        return c[0]
      end
    end
    return false
  end
  
  # returns id of the newest commit.
  # returns false if no commits.
  def getNewestCommit
    if @commits.size > 0
      return @commits.last[0]
    end
    return false
  end
  
  
  # returns id of the parent-commit of the commit with the given id.
  # returns false if no commit found and nil if given commit is the commit-root
  def getParentOfCommit(commit_id)
    c = @repo.commit(commit_id)
    if c == nil
      return false
    elsif c.parents[0] == nil
      return nil
    else
      return c.parents[0].sha
    end
  end
  
  def getNewestCommitId
    begin
      c = @repo.commits.first.id
      return c
    rescue
      return nil
    end
  end
  
  
  # marks commit with the given id as reported to visualrest server
  def commitReported(commit_id)
    @commits.each_index do |i|
      if @commits[i][0] == commit_id
        @commits[i][1] = true
        File.open( @@commits_metafile, 'w' ) do |out|
          YAML.dump( @commits, out )
        end
        return true
      end
    end
    return false
  end
  
  
  def getCommitLocation(commit_hash)
    
    default_location = {'latitude' => 0, 'longitude' => 0} #
    location = nil
    if @commits == nil
      return default_location
    else

      @commits.each_index do |i|
        puts @commits[i][0]
        if @commits[i][0] == commit_hash
          location = {'latitude' => @commits[i][2]['latitude'].to_f, 'longitude' => @commits[i][2]['longitude'].to_f}
        end
      end
      
      if location == nil
        location = default_location
      end
    end
    return location
  end
  
  
  # creates trace to visualReST
  def createTraceToVR(uri, path, location)
    
    # Adding to the git
    addNewFilesToRepo
    commitChanges(location)
    
    # Fetching the blob tha was created, when file was added to the git
    d_blob = @@gitusage.getBlobByFilepath(path)
    
    if d_blob
      # blob_hash ja uri metatiedostoon
      @vR_branches[d_blob.id] = uri.to_s
      File.open( @@vR_branches_metafile, 'w' ) do |out|
        YAML.dump( @vR_branches, out )
      end
      puts "Trace to the file origin created!"
    else
      puts "Blob of the downloaded file not found from repo!"
    end
    
    
  end
  
  
  
  private
  
  def fillFilelistFromTree(tree, path, date, blob_id_as_key = false)
    tree.contents.each do |c|
      if c.class == Grit::Blob
        if blob_id_as_key
          @filelist[c.id] = {"blob_hash" => c.id, "name" => c.name, "path" => path, "filetype" => c.mime_type, "size" => c.size, "filedate" => date}
        else
          @filelist[path + c.name] = {"blob_hash" => c.id, "name" => c.name, "path" => path, "filetype" => c.mime_type, "size" => c.size, "filedate" => date}
        end
      elsif c.class == Grit::Tree
        fillFilelistFromTree(c, path + c.name + "/", date, blob_id_as_key)
      end
    end
  end

  def updateCommitsMetafile
    # list of commit-ids from first to last
    revlist = @git.rev_list({}, 'master').split("\n").reverse
    
    # add missing commit entrys to metafile
    revlist.each_index do |i|
      if @commits[i][0] != revlist[i]
        @commits.insert(i, [revlist[i], false])
      end
    end
    File.open( @@commits_metafile, 'w' ) do |out|
      YAML.dump( @commits, out )
    end
  end


  def addCommitToMetafile(commit_id, updatedToServer, location)
    # update metafile
    @commits.push([commit_id, updatedToServer, location])
    File.open( @@commits_metafile, 'w' ) do |out|
      YAML.dump( @commits, out )
    end
  end

  
end