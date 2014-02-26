package install::seqwareVagrant;

 use strict;
 use warnings;
 
 sub all {
   my ($class, $ssh, $branch, $number_of_nodes, $scheduler) = @_;

   download($ssh, $branch);
   create_template($ssh, $number_of_nodes, $scheduler);

 }

 sub download {
   my ($ssh, $branch) = @_;

   print "downloading SeqWare Vagrant\n";

   $ssh->capture('mkdir -p ~/git');
   $ssh->error and die "Couldn't make git directory: ".$ssh->error;

#   $ssh->capture('cd git', "git clone git://github.com/SeqWare/vagrant.git -b $branch");
#   $ssh->error and die "Couldn't download SeqWare Vagrant: ". $ssh->error;

 }

 sub create_template {
   my ($ssh, $number_of_nodes, $scheduler);


 }

1;
