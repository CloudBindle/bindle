#PanCancer Gateway

##Setting up Gatway

###Create a gateway node on your plaform  

1. Make sure name of node contains "gateway"

2. Make sure your pem file is added

3. Use ubuntu 12.04

4. Copy your private key to your gateway node

###Login to node

####Install Packages

#####Using CPAN:
   NEED libyaml-perl
   sudo cpan install Net::OpenSSH  
   sudo cpan install File::Basename  
   sudo cpan install Getopt::Euclid  
   sudo cpan install Config::Simple  

#####Using apt repositories:
   sudo apt-get install make
   sudo apt-get install libyaml-perl
   sudo apt-get install libfile-basedir-perl  
   sudo apt-get install perl-Getopt-Euclid  
   sudo apt-get install libconfig-simple-perl  


####Clone from git

#####If you dont have git installed:

sudo apt-get install git

#####Clone PanCancer-Gatway from GitHub:

mkdir git; cd git; git clone https://github.com/a8wright/PanCancer-Gateway.git



###Provisioning Launcher

1. Create launcher instance on cloud environment with ubunutu 12.04

2. Create config file in config folder for the launcher you have created

3. Run "perl bin/provisioner.pl -config 'your file name'"

