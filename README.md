
PanCancer Provisioner
############################

Setting up Gatway
#################

Create a gateway node on your plaform 
-I would have "gatway" in the name so that you can recognize it.

Login to node

Install Packages

Using CPAN:

sudo cpan install Net::OpenSSH
sudo cpan install File::Basename
sudo cpan install Getopt::Euclid
sudo cpan install Config::Simple

Using apt repositories:

sudo apt-get install libnet-openssh-perl
sudo apt-get install libfile-basedir-perl
sudo apt-get install perl-Getopt-Euclid
sudo apt-get install libconfig-simple-perl


Clone from git

If you dont have git installed:

sudo apt-get install git

Clone PanCancer-Gatway from GitHub:

git clone git://github.com/a8wright/pancan-gatway



Provisioning Launcher
#####################

1) create launcher instance on cloud environment with ubunutu 12.04

2) create config file in config folder for the launcher you ahve created

2) run provisioner.pl -cluster 'your cluster name'

3) Your done!!! start running seqware

