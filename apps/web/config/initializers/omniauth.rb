Rails.application.config.middleware.use OmniAuth::Builder do
  provider :cas, url: 'https://cas.openadmin.pl/cas', disable_ssl_verification: true
end
