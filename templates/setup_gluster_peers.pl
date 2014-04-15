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

my $out_txt;

open IN, "<$host" or die "Cannot open file $host\n";
while(<IN>) {
  chomp;
  my @a = split /\S+/;
  my $cmd = "gluster peer probe $a[1]";
  if (system($cmd)) {
    print "Problems peering with '$cmd'\n";
  }
}
close IN;

