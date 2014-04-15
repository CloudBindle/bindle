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

my $cmd = "gluster volume create gv0 replica 2 transport tcp";

open IN, "<$host" or die "Cannot open file $host\n";
while(<IN>) {
  chomp;
  my @a = split /\s+/;
  if (scalar(@a) == 2) {
    my $hostname = $a[1]; 
    open DIRS, "<$dir_map" or die "Cannot open file $dir_map\n";
    while(<DIRS>) {
      chomp;
      my $dir = $_;
      $cmd .= " $hostname:$dir";
    }
    close DIRS;
  }
}
close IN;
$cmd .= "; gluster volume start gv0";

if (system($cmd)) {
  print "Problems creating volume with command '$cmd'\n";
}

