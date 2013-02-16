module CheckForUser
  
  def self.append_features(base)
    super
    base.class_eval do # This gets executed as if it was in the class definition
      before_filter :set_user
    end
  end
  
  private

  def ensure_user_is_logged_in
    return true if User.current
    redirect_to_login
  end

  def ensure_user_is_local_or_administrator
    return true if ensure_user_is_logged_in and (User.current.is_local_user? or User.current.administrator?)
    redirect_to_login
  end
  
  def redirect_to_login
    session["return_to"] = request.request_uri
    flash[:warning] = login_message
    redirect_to login_url
    return false
  end
    
  def set_user
    User.current = user_from_session || user_from_http_header
  end
  
  def user_from_session
    return nil unless session[:user_id]
    User.find( session[:user_id] )    
  end
  
  def user_from_http_header
    InstallationHelper.CURRENT_INSTALLATION.user_from_http_header(request)
  end
  
  # Can be overridden in individual controllers
  def login_message
    "You need to be logged in to carry this out.<br/>If you don't have an account, feel free to create one."
  end
end
