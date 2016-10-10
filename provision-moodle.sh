#!/bin/bash
# Setting hostname
MYHOSTNAME=moodle.openadmin.pl
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
# Install moodle LMS
yum -y install moodle php-ldap
yum -y group install mariadb
mv -f /etc/httpd/conf.d/moodle.conf /etc/httpd/conf.d/moodle.conf.bak
systemctl enable httpd
systemctl enable mariadb
systemctl start mariadb
mysql -u root <<-EOF
UPDATE mysql.user SET Password=PASSWORD('adminadmin') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test';
CREATE DATABASE moodle;
FLUSH PRIVILEGES;
EOF
mysql -u root -padminadmin moodle < /vagrant/apps/sql/moodle-cas.sql
sed -i "/^\$CFG->dbhost/s/'';/'localhost';/" /var/www/moodle/web/config.php
sed -i "/^\$CFG->dbname/s/'';/'moodle';/" /var/www/moodle/web/config.php
sed -i "/^\$CFG->dbuser/s/'';/'root';/" /var/www/moodle/web/config.php
sed -i "/^\$CFG->dbpass/s/'';/'adminadmin';/" /var/www/moodle/web/config.php
sed -i "/^\$CFG->wwwroot/s/'http:\/\/localhost\/moodle';/'https:\/\/$MYHOSTNAME';/" /var/www/moodle/web/config.php
# Make self sign certificates trusted for testing enviroment
cp /vagrant/certs/*.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
echo "TLS_REQCERT never" >> /etc/openldap/ldap.conf
# Provision ssl certificates for web server
cp /vagrant/certs/*.key /etc/pki/tls/private/cert.key
cp /vagrant/certs/*.crt /etc/pki/tls/certs/cert.crt
chmod 600 /etc/pki/tls/private/cert.key
chmod 600 /etc/pki/tls/certs/cert.crt
sed -i "/^SSLProtocol/s/-SSLv2/-SSLv2 -SSLv3/" /etc/httpd/conf.d/ssl.conf
sed -i "/^SSLCertificateFile/s/localhost.crt/cert.crt/" /etc/httpd/conf.d/ssl.conf
sed -i "/^SSLCertificateKeyFile/s/localhost.key/cert.key/" /etc/httpd/conf.d/ssl.conf
# Create apache configuration to force SSL connection on Web Server
cat <<EOF >>/etc/httpd/conf.d/01-moodle.conf
<VirtualHost *:80>
  ServerAdmin admin@$DOMAIN
  ServerName $MYHOSTNAME
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^/(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>
EOF
# Create apache configuration to for moodle
cat <<EOF >>/etc/httpd/conf.d/01-moodle-ssl.conf
<VirtualHost *:443>
  ServerAdmin admin@${DOMAIN}
  ServerName $MYHOSTNAME
  SSLEngine on
  SSLCertificateKeyFile  /etc/pki/tls/private/cert.key
  SSLCertificateFile     /etc/pki/tls/certs/cert.crt
  SSLCipherSuite HIGH
  SSLProtocol ALL -SSLv2 -SSLv3
  DocumentRoot /var/www/moodle/web
  <Directory /var/www/moodle/web>
      Require all granted
  </Directory>
  <Directory /var/www/moodle/data>
      Require local
  </Directory>
</VirtualHost>
EOF
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
systemctl start httpd
