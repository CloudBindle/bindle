package install::packages;

  use strict;
  use warnings;
  
  use Data::Dumper;
  use Net::OpenSSH;

  sub all {
    my ($class, $ssh , $vagrant_file_name) = @_;

    set_environment($ssh);
    apt_get_update($ssh);
    general_packages($ssh);
    developer_packages($ssh);
    nokogiri_requirements($ssh);
    nokogiri($ssh);
    download_vagrant($ssh, $vagrant_file_name);
    vagrant($ssh, $vagrant_file_name);
  }
  
  sub set_environment {
    my ($ssh) = @_;

    print "Setting apt-get environment\n";
 
    #setting envionment varialbe for this connection
    $ssh->capture('export "DEBIAN_FRONTEND=noninteractive"');
    $ssh->error and die "Couldn't set environment variables: ".$ssh->error;

    $ssh->capture("sudo -E bash -c 'echo \$DEBIAN_FRONTEND'");
    $ssh->error and die "Couldn't set sudo environment variable: ".$ssh->error;

  }
 
  sub apt_get_update {
    my ($ssh) = @_;

    print "Updating apt-get\n";

    $ssh->capture('sudo apt-get update');
    $ssh->error and die "Couldn't apt-get update: ".$ssh->error;                
  
  }
  
  sub general_packages {
    my ($ssh) = @_;
  
    print "Installing general packages\n";
  
    $ssh->capture('sudo apt-get -y install make build-essential git libjson-perl libtemplate-perl wget');
    $ssh->error and die "Couldn't install apt-get packages: ".$ssh->error; 
  }
  
  sub developer_packages {                                                    
    my ($ssh) =@_;
  
    print "Installing developer packages\n";
  
    $ssh->capture('sudo apt-get -y install ruby1.9.1-dev ruby1.9.1 ri1.9.1 rdoc1.9.1 irb1.9.1 libreadline-ruby1.9.1 libruby1.9.1 libopenssl-ruby libgemplugin-ruby');
    $ssh->error and die "Couldn't install ruby developer packages: ".$ssh->error;
  
  }  
  
  sub nokogiri_requirements {
    my ($ssh) = @_;
  
    print "Installing nokogiri requirements\n";

    $ssh->capture('sudo apt-get -y install libxslt-dev libxml2-dev');
    $ssh->error and die "Couldn't install nokogiri requirements: ".$ssh->error; 
  }
  
  sub nokogiri {
    my ($ssh) = @_;
  
    print "Installing nokogiri\n";

    #create .irbrc file if does not exist
    $ssh->capture('touch .irbrc || exit');
    $ssh->error and die "Couldn't create .irbrc file if does not exist: ".$ssh->error;
 
    #that is required to using rubygems
    $ssh->capture("grep -q 'require \'rubygems\'' .irbrc || echo 'require \'rubygems\'' >> .irbrc");
    $ssh->error and die "Couldn't add environment variables to .irbrc: ". $ssh->error;

  
    $ssh->capture("sudo ruby -e 'require \"rubygems\"\n
                                 begin\n
                                   require \"nokogiri\"\n
                                 rescue LoadError\n 
                                   system(\"gem install nokogiri -v 1.5.3 --quiet\")\n
                                  end\n'");
    $ssh->error and die "Couldn't install nokogiri: ".$ssh->error;
  }
  
  sub download_vagrant {
    my ($ssh, $vagrant_file_name) = @_;
  
    $ssh->pipe_out("mkdir -p ~/Downloads/");
    $ssh->error and die "Couldn't create Downloads folder: ".$ssh->error;

    print "Downloading vagrant if not newest version\n";

    $ssh->capture( "cd Downloads; wget --quiet -N ~/Downloads/ http://dl.bintray.com/mitchellh/vagrant/$vagrant_file_name"); 
  }

  sub vagrant {
    my ($ssh, $vagrant_file_name) = @_;

    print "Installing Vagrant\n";

    $ssh->capture("sudo dpkg -i ~/Downloads/$vagrant_file_name");
    $ssh->error and die "Couldn't install vagrant: ".$ssh->error;

  }

1;
