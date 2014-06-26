use strict;
use Getopt::Long;

# PURPOSE:
# This script attempts to probe peer all the gluster hosts
# ASSUMPTIONS:
# *
# TODO
# * 

my $host;

GetOptions (
  "host=s" => \$host
);

my $vol_report = `cat /vagrant/volumes_report.txt`;
# if there are no volumes present, don't set up gluster volumes!
if ($vol_report eq ""){
  print "Not Setting up gluster peers because no gluster devices/directory were specified in the config file!\n";
  exit;
}


my $out_txt;

open IN, "<$host" or die "Cannot open file $host\n";
while(<IN>) {
  chomp;
  my @a = split /\s+/;
  next if (scalar(@a) != 2);
  my $cmd = "gluster peer probe $a[1]";
  print "CMD: $cmd\n";
  if (system($cmd)) {
    print "Problems peering with '$cmd'\n";
    print " Will try restarting daemon...\n";
    system("/etc/init.d/glusterfs-server restart");
    sleep 15;
    if (system($cmd)) {
      my $output = `$cmd`;
      print "Tried again but still problems peering with '$cmd' output is '$output'\n";
    }
  }
  sleep 5;
}
close IN;

