package install::seqwareVagrant;

 use strict;
 use warnings;
 
 sub all {
   my ($class, $ssh, $number_of_nodes, $scheduler) = @_;

   create_template($ssh, $number_of_nodes, $scheduler);

 }

 sub install {
   my ($class, $ssh, $branch) = @_;

   print "Cloning SeqWare Vagrant\n";

   $ssh->capture('mkdir -p ~/git');
   $ssh->error and die "Couldn't make git directory: ".$ssh->error;

 
   $ssh->capture("cd git; if [ -d vagrant ]; then (cd vagrant && git pull); else git clone git://github.com/SeqWare/vagrant.git -b $branch ~/git/vagrant;fi");
   $ssh->error and die "Couldn't clone SeqWare Vagrant: ". $ssh->error;

 }

 sub comment_network {
   my ($class, $ssh) = @_;

   print "Commenting out network\n";

   $ssh->capture("sed -e '/os.network \= \"\%\{OS_NETWORK\}\"/ s/^#*/#/' -i ~/git/vagrant/templates/Vagrantfile_part.template");
   $ssh->error and die "Couldn't comment out netowrk line in SeqWare Vagrant". $ssh->error;

 }

 sub comment_float_ip {
   my ($class, $ssh) = @_;
   print "Commenting out float ip\n";

   $ssh->capture("sed -e '/os.floating_ip \= \"\%\{OS_FLOATING_IP\}\"/ s/^#*/#/' -i ~/git/vagrant/templates/Vagrantfile_part.template");
   $ssh->error and die "Couldn't comment out netowrk line in SeqWare Vagrant". $ssh->error;


 }

 sub create_template {
   my ($ssh, $number_of_nodes, $scheduler) = @_;


 }

 sub run {
   my ($ssh) = @_;

 }

1;
