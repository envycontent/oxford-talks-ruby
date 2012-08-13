require 'openssl'
require 'webrick'
require 'base64'

class Login::OxfordssologinController < ApplicationController
  before_filter :store_return_url_in_session

	def store_return_url_in_session
    session["return_to"] = params[:return_url] if (params[:return_url] && params[:return_url] != '/login/logout') 
	end

  def go_to_secure_webauth
    # Going to https will require webauth authentication
    #returnTo = (params[:return_url].nil? ? "/" : params[:return_url])
    redirect_to "https://" + request.host + (original_url.nil? ? "" : original_url)
  end

  def external_user_login
    puts "External User Login"
    user = User.find_by_email params[:email]
    if user
      if user.password && params[:password] == user.password
        session[:user_id ] = user.id
        post_login_actions
    	else
  	    flash[:login_error] = "Password not correct"
  	    @email = user.email
  	    render :action => 'index'
  	  end
    else
      flash[:login_error] = "I have no record of this email"
      render :action => 'index'
    end
  end

	def logout
    # Same logic as in the InstallationHelper, although can't access it from here, since
    # the installation helper also references us.
    # Doesn't boolean logic work in ruby?
    if not User.current.nil? and not User.current.crsid.nil?
      was_local_user = true
    else
      was_local_user = false
    end
	  User.current = nil
	  session[:user_id ] = nil
	  session["return_to"] = nil
	  flash[:confirm] = "You have been logged out."
    if was_local_user
      redirect_to_url "https://webauth.ox.ac.uk/logout"
    end
	end

  def send_password
    @user = User.find_by_email params[:email]
    if @user
      @user.send_password
      render :action => 'password_sent'
    else
      flash[:error] = "I'm sorry, but #{params[:email]} is not listed on this system. (note that is is case sensitive)"
      render :action => 'lost_password'
    end
  end

  def return_to_original_url
    redirect_to original_url
    session["return_to"] = nil
  end

  def original_url
    original_url = session["return_to"] || (session[:user_id] && list_url(:id => User.find(session[:user_id]).personal_list ))
    return original_url
  end

  private

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

