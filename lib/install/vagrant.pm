package install::vagrant;

  use strict;
  use warnings;
  
  use Data::Dumper;
  use Net::OpenSSH;
 
  sub vagrant {
    my ($class, $ssh, $vagrant_file_name) = @_;
  
    print "installing vagrant\n";
  
    $ssh->capture("sudo dpkg --install /home/ubunut/Downloads/$vagrant_file_name");
    $ssh->error and die "Couldn't install vagrant: ".$ssh->error;
  }


1;























































