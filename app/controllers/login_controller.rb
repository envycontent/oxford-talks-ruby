class LoginController < InstallationHelper.CURRENT_INSTALLATION.loginController
  def send_password_reset
    user = User.find_by_email(params[:email])
    if not user.nil?
      user.create_password_reset_key
      user.save
      user.send_password_reset_request
    end
    render :action => 'password_reset_sent'
  end

  def external_user_login
    user = User.authenticate(params[:email], params[:password])
    if user
      session[:user_id] = user.id
      post_login_actions
    else
      flash[:login_error] = "User not found, or password incorrect"
      render :action => 'index'
    end
  end

  def post_login_actions
    user = User.find(session[:user_id])
    if user.needs_an_edit?
      redirect_to user_url(:action => 'edit',:id => user )
    else
 		  return_to_original_url
 		end
	  flash[:confirm] = "You have been logged in."
	  user.update_attribute :last_login, Time.now
  end
end
