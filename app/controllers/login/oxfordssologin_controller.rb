require 'openssl'
require 'webrick'
require 'base64'

class Login::OxfordssologinController < ApplicationController
  before_filter :store_return_url_in_session

  def go_to_secure_webauth
    # Going to https will require webauth authentication
    #returnTo = (params[:return_url].nil? ? "/" : params[:return_url])
    redirect_to "https://" + request.host + (original_url.nil? ? "" : original_url)
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

  def return_to_original_url
    redirect_to original_url
    session["return_to"] = nil
  end

  def original_url
    original_url = session["return_to"] || (session[:user_id] && list_url(:id => User.find(session[:user_id]).personal_list ))
    return original_url
  end

  private

	def store_return_url_in_session
    session["return_to"] = params[:return_url] if (params[:return_url] && params[:return_url] != '/login/logout') 
	end
end

