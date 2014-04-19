use strict;
use Getopt::Long;

# PURPOSE:
# This script attempts to start the gluster volume
# ASSUMPTIONS:
# *
# TODO
# * 

my $host;
my $dir_map;

GetOptions (
  "host=s" => \$host,
  "dir-map=s" => \$dir_map,
);

my $cmd = "gluster peer status; gluster volume info; gluster volume status; gluster volume create gv0 replica 2 transport tcp";

open DIRS, "<$dir_map" or die "Cannot open file $dir_map\n";
while(<DIRS>) {
  chomp;
  my $dir = $_;
  open IN, "<$host" or die "Cannot open file $host\n";
  while(<IN>) {
    chomp;
    my @a = split /\s+/;
    if (scalar(@a) == 2) {
      my $hostname = $a[1];
      $cmd .= " $hostname:$dir";
    }
  }
  close IN;
}
close DIRS;

# disable built-in NFS server so it doesn't interfer with other NFS exports
$cmd .= "; gluster volume set gv0 nfs.disable on";
# turn on the volume
$cmd .= "; gluster volume start gv0; gluster peer status; gluster volume info; gluster volume status;";

print "GLUSTER SETUP WITH COMMAND: $cmd\n";

if (system($cmd)) {
  print "Problems creating volume with command '$cmd'\n";
}

