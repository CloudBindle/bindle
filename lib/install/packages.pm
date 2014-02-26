package install::packages;

  use strict;
  use warnings;
  
  use autodie;
  use Data::Dumper;

  sub all {
    my ($class, $ssh , $vagrant_file_name) = @_;

    apt_get_update($ssh);
    general_packages($ssh);
    developer_packages($ssh);
    nokogiri_requirements($ssh);
    nokogiri($ssh);
    download_vagrant($ssh, $vagrant_file_name);
    vagrant($ssh, $vagrant_file_name);
  
  }
  
  sub apt_get_update {
    my ($ssh) = @_;

    $ssh->capture('sudo apt-get update');
    $ssh->error and die "Couldn't apt-get update".$ssh->error;                
  
  }
  
  sub general_packages {
    my ($ssh) = @_;
  
    print "installing general packages\n";
  
    $ssh->capture('sudo apt-get -q -y install dialog make build-essential git libjson-perl libtemplate-perl wget');
    $ssh->error and die "Couldn't install apt-get packages".$ssh->error; 
  }
  
  sub developer_packages {                                                    
    my ($ssh) =@_;
  
    print "installing developer packages\n";
  
    $ssh->capture('sudo apt-get -q -y install ruby1.9.1-dev ruby1.9.1 ri1.9.1 rdoc1.9.1 irb1.9.1 libreadline-ruby1.9.1 libruby1.9.1 libopenssl-ruby libgemplugin-ruby');
    $ssh->error and die "Couldn't install ruby developer packages".$ssh->error;
  
  }  
  
  sub nokogiri_requirements {
    my ($ssh) = @_;
  
    print "installing nokogiri requirements\n";
  
    $ssh->capture('sudo apt-get -q -y install libxslt-dev libxml2-dev');
    $ssh->error and die "Couldn't install nokogiri requirements".$ssh->error; 
  }
  
  sub nokogiri {
    my ($ssh) = @_;
  
    print "installing nokogiri\n";
  
    $ssh->capture('sudo gem install nokogiri -v 1.5.3 --quiet');
    $ssh->error and die "Couldn't install nokogiri".$ssh->error;
  }
  
  sub download_vagrant {
    my ($ssh, $vagrant_file_name) = @_;
  
    print "downloading vagrant\n";
  
    my ($pty) = $ssh->open2pty('wget', "http://dl.bintray.com/mitchellh/vagrant/$vagrant_file_name"); 
  }
  
  sub vagrant {
    my ($ssh, $vagrant_file_name) = @_;
  
    print "installing vagrant\n";
  
    my ($pty) = $ssh->open2pty("sudo dpkg --install $vagrant_file_name")
                                   or die ("unable to run dpkg for vagrant"); 
    $ssh->error and die "Couldn't install vagrant".$ssh->error;
    print Dumper $pty;
  }
  


1;























































