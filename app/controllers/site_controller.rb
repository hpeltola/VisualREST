class SiteController < ApplicationController
  def index
    
    @title = "Welcome to VisualRest!"
    
    @news = FrontpageNews.find(:all, :order => "created_at DESC")
    
    @host = @@http_host
    respond_to do |format|
      format.html {render :index, :layout=>true }
      format.atom {render :getnews, :layout=>false }
    end
    
    
  end

  def about
    @title = "About VisualRest2"
  end

  def help
    @title = "VisualRest Help"
  end

  def addnews
    
    if session[:username]
      @user = User.find_by_username(session[:username])
    else
      redirect_to :action => "login", :controller => "user"
    end
    
    render :update do |page|
      page["addnews"].replace_html :partial => 'addnews' 
    end
  end

  def createNews
    if session[:username]
      @user = User.find_by_username(session[:username])
    else
      redirect_to :action => "login", :controller => "user"
    end
    if params[:frontpage_news]
      @news = FrontpageNews.new(params[:frontpage_news])
      @news.user_id = @user.id
      if @news.description.length < FrontpageNews::NEWS_MIN_LENGTH
        flash[:notice] = "Message too short! (Minimum #{FrontpageNews::NEWS_MIN_LENGTH.to_s})"
        redirect_to :action => "index", :controller => "site"
        return
      end
      
      if @news.save
        flash[:notice] = "News added!"
        redirect_to :action => "index", :controller => "site"
        return
      end
    end
    
  end

end
