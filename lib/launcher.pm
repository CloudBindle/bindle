package launcher;

  use strict;
  use warnings;

  use File::Basename;

  sub connect {
     my ($class, $host, $options) = @_;

     print "Connecting to launcher\n"; 
  
     my $ssh = Net::OpenSSH->new( $host, %$options);
     $ssh->error and die "Couldn't establish SSH connection: ". $ssh->error;   

     return $ssh;
  }

  sub add_pem_file {
     my ($class, $ssh, $options) = @_;
     
     print "Adding ssh pem file\n"; 

     my $launcher_key_path = "/home/$options->{user}/.ssh/";  
     $ssh->scp_put($options->{key_path}, $launcher_key_path) 
     or die "scp failed: ". $ssh->error; 

     my $launcher_key_file = $launcher_key_path.basename($options->{key_path});  

     $ssh->capture('chmod'." 600 $launcher_key_file"); 
     $ssh->error and die "Couldn't change the permissions to the key file".$ssh->error; 
  }
1;
