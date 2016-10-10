# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
required_plugins = %w( vagrant-hostmanager )
required_plugins.each do |plugin|
  system "vagrant plugin install #{plugin}" unless Vagrant.has_plugin? plugin
end

Vagrant.configure("2") do |config|

  Vagrant.require_version ">= 1.8.5"
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = false
  # Configuration for CAS server machine
  config.vm.define "cas", primary: true do |cas|
    # Provider for CAS server machine
    cas.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
       vb.gui = false
    # Customize the amount of memory on the VM:
       vb.memory = "1024"
     end
    # cas.vm.box = "boxcutter/centos72"
    cas.vm.box = "bento/centos-7.2"
    cas.vm.hostname = "cas.openadmin.pl"
    cas.vm.network "private_network", ip: "172.20.1.10"
    # Forwarded ports
    # cas.vm.network "forwarded_port", guest: 80, host: 8000, auto_correct: true
    # cas.vm.network "forwarded_port", guest: 443, host: 4443, auto_correct: true
    # Provisinng for cas server
    cas.vm.provision "shell", path: "provision-cas.sh"
    # Show this message to the user
    cas.vm.post_up_message = "********************************* CAS SERVER INFORMATION ************************************\n"\
                             "Use address https://cas.openadmin.pl to access Tomcat administration on cas server\n"\
                             "username: admin password: adminadmin\n"\
                             "Use address https://cas.openadmin.pl/ldapadmin to access LDAP catalog administration page\n"\
                             "Login with cn=admin,dc=openadmin,dc=pl and password: adminadmin\n"\
                             "Use address https://cas.openadmin.pl/cas to drirectly access CAS server application \n"\
                             "*********************************************************************************************"
  end

  # Configuration for WEB1 server machine
  config.vm.define "web1" do |web1|
    # Provider for WEB1 server machine
    web1.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
       vb.gui = false
    # Customize the amount of memory on the VM:
       vb.memory = "512"
     end
    # cas.vm.box = "boxcutter/centos72"
    web1.vm.box = "bento/centos-7.2"
    web1.vm.hostname = "web1.openadmin.pl"
    web1.vm.network "private_network", ip: "172.20.1.11"
    # Forwarded ports
    # web1.vm.network "forwarded_port", guest: 80, host: 8001, auto_correct: true
    # Provisinng for cas server
    web1.vm.provision "shell", path: "provision-web1.sh"
    # Show this message to the user
    web1.vm.post_up_message = "************************* WEB1 SERVER INFORMATION ****************************\n"\
                              "Use address https://web1.openadmin.pl to accses WEB1 web application \n"\
                              "********************************************************************************"
  end
  #
  # Configuration for WEB2 server machine
  config.vm.define "web2" do |web2|
    # Provider for WEB1 server machine
    web2.vm.provider "virtualbox" do |vb|
    # Display the VirtualBox GUI when booting the machine
       vb.gui = false
    # Customize the amount of memory on the VM:
       vb.memory = "512"
     end
    # cas.vm.box = "boxcutter/centos72"
    web2.vm.box = "bento/centos-7.2"
    web2.vm.hostname = "web2.openadmin.pl"
    web2.vm.network "private_network", ip: "172.20.1.12"
    # Forwarded ports
    # web2.vm.network "forwarded_port", guest: 80, host: 8002, auto_correct: true
    # Provisinng for cas server
    web2.vm.provision "shell", path: "provision-web2.sh"
    # Show this message to the user
    web2.vm.post_up_message = "************************* WEB1 SERVER INFORMATION ****************************\n"\
                            "Use address https://web2.openadmin.pl to accses WEB2 web application \n"\
                            "********************************************************************************"
  end

  # # Configuration for Moodle server machine
  # config.vm.define "moodle" do |moodle|
  #   # Provider for Moodle server machine
  #   moodle.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #      vb.gui = false
  #   # Customize the amount of memory on the VM:
  #      vb.memory = "512"
  #    end
  #   # cas.vm.box = "boxcutter/centos72"
  #   moodle.vm.box = "bento/centos-7.2"
  #   moodle.vm.hostname = "moodle.openadmin.pl"
  #   moodle.vm.network "private_network", ip: "172.20.1.13"
  #   # Forwarded ports
  #   # moodle.vm.network "forwarded_port", guest: 80, host: 8003, auto_correct: true
  #   # moodle.vm.network "forwarded_port", guest: 443, host: 10443, auto_correct: true
  #   # Provisinng for moodle server
  #   moodle.vm.provision "shell", path: "provision-moodle.sh"
  #   # Show this message to the user
  #   moodle.vm.post_up_message = "************************* MOODLE SERVER INFORMATION **************************\n"\
  #                             "Use address https://moodle.openadmin.pl to access Moodle ILS/LMS system \n"\
  #                             "********************************************************************************"
  # end
  #
  # Configuration for Redmine server machine
  # config.vm.define "redmine" do |redmine|
  #   # Provider for Moodle server machine
  #   redmine.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #      vb.gui = false
  #   # Customize the amount of memory on the VM:
  #      vb.memory = "512"
  #    end
  #   # cas.vm.box = "boxcutter/centos72"
  #   redmine.vm.box = "bento/centos-7.2"
  #   redmine.vm.hostname = "redmine.openadmin.pl"
  #   redmine.vm.network "private_network", ip: "172.20.1.14"
  #   # Provisinng for redmine server
  #   redmine.vm.provision "shell", path: "provision-redmine.sh"
  #   # Show this message to the user
  #   redmine.vm.post_up_message = "************************* REDMINE SERVER INFORMATION *************************\n"\
  #                               "Use address https://redmine.openadmin.pl to access Redmine system \n"\
  #                               "********************************************************************************"
  # end

  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  # Setting hostname


  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.

end
