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
  my @a = split /\s+/;
  next if (scalar(@a) != 2);
  my $cmd = "gluster peer probe $a[1]";
  print "CMD: $cmd\n";
  if (system($cmd)) {
    print "Problems peering with '$cmd'\n";
    sleep 5;
    if (system($cmd)) {
      my $output = `$cmd`;
      print "Tried again but still problems peering with '$cmd' output is '$output'\n";
    }
  }
}
close IN;

