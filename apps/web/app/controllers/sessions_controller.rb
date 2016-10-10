class SessionsController < ApplicationController

  def new
    redirect_to '/auth/cas'
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.where(:provider => auth['provider'],
                      :uid => auth['uid'].to_s).first || User.create_with_omniauth(auth)
    reset_session
    session[:user_id] = user.id
    redirect_to root_url, :notice => 'Signed in!'
  end

  def destroy
    reset_session
    redirect_to root_url, :notice => 'Signed out!'
  end

  def cas_logout
    reset_session

    strategy = strategy = OmniAuth::Strategies::CAS.new(nil, url: 'https://cas.openadmin.pl/cas', disable_ssl_verification: true)
    service_url = root_url + 'auth/cas/callback'
    full_logout_url = strategy.cas_url + strategy.append_params('/logout', service: service_url)
    redirect_to full_logout_url
  end

  def failure
    redirect_to root_url, :alert => "Authentication error: #{params[:message].humanize}"
  end

end
