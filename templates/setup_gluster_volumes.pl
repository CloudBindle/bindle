use strict;
use Getopt::Long;

# PURPOSE:
# This script attempts to configure directories for sharing via gluster
# ASSUMPTIONS:
# * the EBS/ephemeral disks have all been formated with xfs and mounted
# * this just creates a gluster directory on every specified directory and writes it out to a new file
# TODO
# * 

my $dir_map;
my $output;
my $blacklist;
my $whitelist;

GetOptions (
  "dir-map=s" => \$dir_map,
  "output=s" => \$output,
);

my $out_txt;

open IN, "<", $dir_map or die "Cannot open file $dir_map: $!\n";
open OUT, ">", $output or die "Cannot open file $output: $!\n";
while(<IN>) {
  chomp;
  my $location = $_;
  $location = "$location/gluster";
  if (system("mkdir -p $location")) {
    print "Problems creating directory $location\n";
  }
  $out_txt .= "$location\n";
}
print OUT $out_txt;
close OUT;
close IN;

