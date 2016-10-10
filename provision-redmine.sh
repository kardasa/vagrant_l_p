#!/bin/bash
# Setting hostname
MYHOSTNAME=redmine.openadmin.pl
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
# Install epel release
yum -y install epel-release
yum -y group install mariadb
# Install packages needed to run and build Redmine application with dependencies
yum -y install mod_passenger rubygem-bundler ruby-devel zlib-devel mysql-devel gcc
systemctl enable httpd
systemctl enable mariadb
systemctl start mariadb
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('adminadmin') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test';
CREATE DATABASE redmine;
FLUSH PRIVILEGES;
EOF
mkdir -p /var/www/redmine
cd /var/tmp
wget http://www.redmine.org/releases/redmine-2.6.10.tar.gz
tar -xvf redmine-2.6.10.tar.gz
wget https://github.com/pencil/redmine_activerecord_session_store/archive/master.zip
wget -O redmine_cas.zip https://github.com/ninech/redmine_cas/archive/master.zip
yum -y install unzip
unzip master.zip
unzip redmine_cas.zip
mv redmine-2.6.10/* /var/www/redmine
mkdir -p /var/www/redmine/plugins/redmine_activerecord_session_store
mkdir -p /var/www/redmine/plugins/redmine_cas
mv redmine_activerecord_session_store-master/* /var/www/redmine/plugins/redmine_activerecord_session_store/
mv redmine_cas-master/* /var/www/redmine/plugins/redmine_cas/
chown -R root. /var/www/redmine
chmod -R o+wX /var/www/redmine/log
chmod -R o+wX /var/www/redmine/tmp
chmod -R o+wX /var/www/redmine/files
chmod -R o+wX /var/www/redmine/public/plugin_assets
restorecon -R /var/www/redmine
# Create database config for Rails Application
cat <<EOF >> /var/www/redmine/config/database.yml
production:
  adapter: mysql2
  database: redmine
  host: localhost
  username: root
  password: adminadmin
EOF
# Install application dependencies
cd /var/www/redmine
bundle install --without development test rmagick
bundle exec rake generate_secret_token
# Clean redmine instalation
# RAILS_ENV=production bundle exec rake db:migrate
# RAILS_ENV=production bundle exec rake redmine:plugins:migrate
# RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data
# Full redmine configuration with forced Authentication
mysql -u root -padminadmin redmine < /vagrant/apps/sql/redmine-cas.sql
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
cat <<EOF >>/etc/httpd/conf.d/01-redmine.conf
<VirtualHost *:80>
  ServerAdmin admin@$DOMAIN
  ServerName $MYHOSTNAME
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^/(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>
EOF
# Create apache configuration for redmine thin via proxy pass
cat <<EOF >>/etc/httpd/conf.d/01-redmine-ssl.conf
<VirtualHost *:443>
  ServerAdmin admin@${DOMAIN}
  ServerName $MYHOSTNAME
  SSLEngine on
  SSLCertificateKeyFile  /etc/pki/tls/private/cert.key
  SSLCertificateFile     /etc/pki/tls/certs/cert.crt
  SSLCipherSuite HIGH
  SSLProtocol ALL -SSLv2 -SSLv3
  DocumentRoot /var/www/redmine/public
  <Directory /var/www/redmine/public>
          AllowOverride all
          Options -MultiViews
          Require all granted
  </Directory>
</VirtualHost>
EOF
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
systemctl start httpd
