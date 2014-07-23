package launch;
use common::sense;
use Net::OpenSSH;
use IPC::System::Simple;


sub connect_to_host{
     my ($class,$host, $ssh_key_name) = @_;
     my %options = (
        user => "ubuntu",
        key_path => "/home/ubuntu/.ssh/$ssh_key_name.pem",
        strict_mode => 0,
        #master_opts => '-vvv',
        master_opts => [-o => "StrictHostKeyChecking=no"]
     );

     system("rm -r ~/.ssh/known_hosts");
     print "Connecting to $host\n";

     my $ssh = Net::OpenSSH->new( $host, %options);
     $ssh->error and die "Couldn't establish SSH connection: ". $ssh->error;
     return $ssh;
}

sub launch_cluster{
    my ($class,$pl_cmd) = @_;
    system("$pl_cmd"); 
}

1;
