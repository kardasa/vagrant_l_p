#!/bin/bash
# Setting hostname
MYHOSTNAME=web1.openadmin.pl
MYHOSTNAMESHORT=$(echo $MYHOSTNAME | cut --delimiter="." -f 1)
DOMAIN=$(echo $MYHOSTNAME | cut --delimiter="." -f 2,3)
#hostnamectl set-hostname $MYHOSTNAME
#sed -i "/^127.0.0.1/ s/$/ $MYHOSTNAMESHORT $MYHOSTNAME/" /etc/hosts
sed -i "/^::1/ s/$/ $MYHOSTNAMESHORT $MYHOSTNAME/" /etc/hosts
IPS=$(ip addr show | grep inet | grep -v 127.0.0.1 | grep -v ::1 | awk '{print $2}' | cut --delimiter="/" -f 1)
for ip in $IPS; do
  echo "${ip} $MYHOSTNAMESHORT $MYHOSTNAME" >> /etc/hosts
done
# We want to be secure (at least a little bit) event in vagrant
systemctl enable firewalld
systemctl start firewalld
# I hate vi part
yum -y install nano
echo "set nowrap" >>/etc/nanorc
sed -i '/^# include /s/^#//' /etc/nanorc
cat <<EOF >>/etc/profile.d/nano.sh
export VISUAL="/usr/bin/nano"
export EDITOR="/usr/bin/nano"
EOF
# Apache Web server installation and configuration part
yum -y group install web-server
yum -y install epel-release
mkdir -p /var/www/web
cp -r /vagrant/apps/web/* /var/www/web
# Install packages needed to run and build Rails application with dependencies
yum -y install mod_passenger rubygem-bundler ruby-devel zlib-devel sqlite sqlite-devel gcc gcc-c++
mkdir /var/www/web/tmp /var/www/web/log
chown -R root. /var/www/web
chmod -R o+wX /var/www/web/tmp /var/www/web/log
cat <<EOF >/var/www/web/config/secrets.yml
production:
  secret_key_base: 1e86c675f1b669991c4efd09459cea38e7c524507a63be1e6390926b0c20c6f8d5844dd68d520abea1c8a4c0db67c8875660949d9025105b8fa5af6869849b60
EOF
cd /var/www/web
bundle install --without development test
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production rake assets:precompile
chmod 777 /var/www/web/db
chmod 666 /var/www/web/db/production.sqlite3
chmod 666 /var/www/web/log/production.log
restorecon -R /var/www/web
sed -i 's/CAS Test Application/CAS Test Application WEB1/g' /var/www/web/app/views/layouts/application.html.erb
sed -i 's/Welcome/Welcome to Web1 CAS Test Aplication/'  /var/www/web/app/views/visitors/index.html.erb
# Make self sign certificates trusted for testing enviroment
cp /vagrant/certs/*.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
# Provision ssl certificates for web server
cp /vagrant/certs/*.key /etc/pki/tls/private/cert.key
cp /vagrant/certs/*.crt /etc/pki/tls/certs/cert.crt
chmod 600 /etc/pki/tls/private/cert.key
chmod 600 /etc/pki/tls/certs/cert.crt
sed -i "/^SSLProtocol/s/-SSLv2/-SSLv2 -SSLv3/" /etc/httpd/conf.d/ssl.conf
sed -i "/^SSLCertificateFile/s/localhost.crt/cert.crt/" /etc/httpd/conf.d/ssl.conf
sed -i "/^SSLCertificateKeyFile/s/localhost.key/cert.key/" /etc/httpd/conf.d/ssl.conf
# Create apache configuration to force SSL connection on Web Server
cat <<EOF >>/etc/httpd/conf.d/01-web1.conf
<VirtualHost *:80>
  ServerAdmin admin@${DOMAIN}
  ServerName $MYHOSTNAME
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^/(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>
EOF
# Create apache configuration for redmine thin via proxy pass
cat <<EOF >>/etc/httpd/conf.d/01-web1-ssl.conf
<VirtualHost *:443>
  ServerAdmin admin@${DOMAIN}
  ServerName $MYHOSTNAME
  SSLEngine on
  SSLCertificateKeyFile  /etc/pki/tls/private/cert.key
  SSLCertificateFile     /etc/pki/tls/certs/cert.crt
  SSLCipherSuite HIGH
  SSLProtocol ALL -SSLv2 -SSLv3
  DocumentRoot /var/www/web/public
  <Directory /var/www/web/public>
          AllowOverride all
          Options -MultiViews
          Require all granted
  </Directory>
</VirtualHost>
EOF
systemctl enable httpd
systemctl start httpd
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
