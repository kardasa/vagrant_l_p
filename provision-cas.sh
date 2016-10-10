#!/bin/bash
# Setting hostname
MYHOSTNAME=cas.openadmin.pl
MYHOSTNAMESHORT=$(echo $MYHOSTNAME | cut --delimiter="." -f 1)
DOMAIN=$(echo $MYHOSTNAME | cut --delimiter="." -f 2,3)
#hostnamectl set-hostname $MYHOSTNAME
#sed -i "/^127.0.0.1/ s/$/ $MYHOSTNAMESHORT $MYHOSTNAME/" /etc/hosts
sed -i "/^::1/ s/$/ $MYHOSTNAMESHORT $MYHOSTNAME/" /etc/hosts
IPS=$(ip addr show | grep inet | grep -v 127.0.0.1 | grep -v ::1 | awk '{print $2}' | cut --delimiter="/" -f 1)
for ip in $IPS; do
  echo "${ip} $MYHOSTNAMESHORT $MYHOSTNAME" >> /etc/hosts
done
# We want to be secure (at least a little bit) even in vagrant
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
systemctl enable httpd
systemctl start httpd
firewall-cmd --permanent --add-service=http
# Tomcat server installation and configuration
yum -y group install web-servlet
sed -i -e "s/<!---* *<\(.*\)> *-->/<\1>/" /etc/tomcat/tomcat-users.xml
systemctl enable tomcat
systemctl start tomcat
# firewall-cmd --permanent --add-port=8080/tcp
# LDAP Server and client installation and configuraton
yum -y install openldap openldap-clients openldap-servers
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown ldap. /var/lib/ldap/DB_CONFIG
systemctl enable slapd
systemctl start slapd
ldapadd -Y EXTERNAL -H ldapi:/// -f /vagrant/ldifs/adminPW.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /vagrant/ldifs/OpenAdminDomain.ldif
ldapadd -x -D cn=admin,dc=openadmin,dc=pl -w adminadmin -f /vagrant/ldifs/DomainConfig.ldif
setsebool -P httpd_can_connect_ldap=1
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
cat <<EOF >>/etc/httpd/conf.d/01-cas.conf
<VirtualHost *:80>
  ServerAdmin admin@$DOMAIN
  ServerName $MYHOSTNAME
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^/(.*) https://%{SERVER_NAME}/\$1 [R,L]
</VirtualHost>
EOF
firewall-cmd --permanent --add-service=https
# Restart apache
systemctl restart httpd
# Provision certificates for Tomcat server
cd /usr/share/tomcat
openssl pkcs12 -export -in /etc/pki/tls/certs/cert.crt -inkey /etc/pki/tls/private/cert.key -out .keystore -name tomcat -password pass:changeit
chmod 600 .keystore
chown tomcat. .keystore
sed -i '/clientAuth="false" sslProtocol="TLS"/{N;s/\n.*//;}' /etc/tomcat/server.xml
sed -n -i '/port="8443" protocol="org.apache.coyote.http11.Http11Protocol"/{x;d;};1h;1!{x;p;};${x;p;}' /etc/tomcat/server.xml
# firewall-cmd --permanent --add-port=8443/tcp
systemctl restart tomcat
# Create apache configuration to force local connection via ProxyPass to Tomcat server
cat <<EOF >>/etc/httpd/conf.d/01-cas-ssl.conf
<VirtualHost *:443>
  ServerAdmin admin@${DOMAIN}
  ServerName $MYHOSTNAME
  SSLEngine on
  SSLCertificateKeyFile  /etc/pki/tls/private/cert.key
  SSLCertificateFile     /etc/pki/tls/certs/cert.crt
  SSLCipherSuite HIGH
  SSLProtocol ALL -SSLv2 -SSLv3
  SSLProxyEngine on
  SSLProxyVerify none
  SSLProxyCheckPeerCN off
  SSLProxyCheckPeerName off
  SSLProxyCheckPeerExpire on
  ProxyPass /phpldapadmin !
  ProxyPass /ldapadmin !
  ProxyPass / https://127.0.0.1:8443/
  ProxyPassReverse / https://127.0.0.1:8443/
</VirtualHost>
EOF
# Provision ssl certificates for slapd server
cp /vagrant/certs/*.key /etc/openldap/certs/cert.key
cp /vagrant/certs/*.crt /etc/openldap/certs/cert.crt
chown ldap. /etc/openldap/certs/cert.crt
chmod 600 /etc/openldap/certs/cert.crt
chown ldap. /etc/openldap/certs/cert.key
chmod 600 /etc/openldap/certs/cert.key
ldapmodify -Y EXTERNAL -H ldapi:/// -f /vagrant/ldifs/tls.ldif
sed -i "/^SLAPD_URLS/s/ldap:\/\/\//ldap:\/\/\/ ldaps:\/\/\//" /etc/sysconfig/slapd
echo "TLS_REQCERT allow" >> /etc/openldap/ldap.conf
echo "BASE dc=$(echo $MYHOSTNAME | cut --delimiter="." -f 2),dc=$(echo $MYHOSTNAME | cut --delimiter="." -f 3)" >> /etc/openldap/ldap.conf
echo "URI ldaps://127.0.0.1:676/ ldap://127.0.0.1:389/" >> /etc/openldap/ldap.conf
# Restart slapd
systemctl restart slapd
# Make connection to ldap possible from other machines - needed by Moodle CAS authorization but have no idea why
firewall-cmd --permanent --add-service=ldap --add-service=ldaps
# PHPLDAPAdmin installation to easy up testing
yum -y install epel-release
yum -y install phpldapadmin
sed -i "s/Require local/Require all granted/" /etc/httpd/conf.d/phpldapadmin.conf
sed -i "s/Local LDAP Server/OpenAdmin LDAP Server/" /etc/phpldapadmin/config.php
sed -i "/^\$servers->setValue('login','attr',/s/uid/dn/" /etc/phpldapadmin/config.php
sed -i "s/\/\/ \$servers->setValue('server','tls',false);/\$servers->setValue('server','tls',true);/" /etc/phpldapadmin/config.php
systemctl restart httpd
# Install maven to build cas on targeted server
yum -y install maven
# Build and install cas aplication on servlet container
mkdir -p /etc/cas
cp /vagrant/cas/etc/cas.properties /etc/cas/
cp /vagrant/cas/etc/log4j2.xml /etc/cas/
chown -R tomcat. /etc/cas/
cd /vagrant/cas
mvn clean package
cp /vagrant/cas/target/cas.war /var/lib/tomcat/webapps/
systemctl restart tomcat
# Reload firewall
firewall-cmd --reload
