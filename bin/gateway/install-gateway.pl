#!/usr/bin/perl 

use strict;
use warnings;

print "Setting up gatway\n";

print "Updating apt-get\n";
system ("sudo apt-get -qq update") 
                             and die "System could not apt-get update: $!";

print "Installing make\n";
system ("sudo apt-get install -qq make perl build-essential curl") 
                             and die "Could not install make: $!"; 

print "Installing Modules\n";
system ("sudo cpan install Net::OpenSSH") 
                             and die "CPAN could not install Net::OpenSSH $!";

system("sudo apt-get install -y libyaml-perl libfile-basedir-perl")
                             and die "Apt-get could not isntall modules: $!";

system("sudo cpan install Getopt::Euclid") 
                             and die "CPAN could not install Getopt::Euclid $!";

system("sudo cpan install Config::Simple")
                             and die "Apt-get could not isntall modules: $!";

print "Installation Complete\n";
