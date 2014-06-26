#! /usr/bin/env perl

use common::sense;
use autodie;

use Getopt::Long;

use File::Basename qw();

my $cluster_name;
GetOptions ( "cluster-name=s" => \$cluster_name, );

die "Specify the option cluster-name with the of the clusters target directory"
        unless(defined $cluster_name);

opendir( my $dh, $cluster_name );

my @vm_dirs;
while( readdir $dh) {
    if ( ($_ =~ /master|worker/) and (-d "$cluster_name/$_") ) {
        `cd $cluster_name/$_; vagrant destroy -f`;
    }
}

`rm -r $cluster_name`;

