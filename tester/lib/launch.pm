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
        master_opts => [-o => "StrictHostKeyChecking=no"]
     );

     system("rm -r ~/.ssh/known_hosts");
     print "Connecting to $host\n";

     my $ssh = Net::OpenSSH->new( $host, %options);
     $ssh->error and die "Couldn't establish SSH connection: ". $ssh->error;
     return $ssh;
}

# terminates all the clusters that were passed in (ex. target-aws-1,target-aws-2)
sub destroy_clusters{
   my ($class,$cluster_blocks) = @_;
   my @blocks = split (/,/,$cluster_blocks);

   for my $cluster_block (@blocks){
       system("perl bin/launcher/destroy_cluster.pl --cluster-name $cluster_block");
       say "Destroyed $cluster_block";
   }

}
1;
