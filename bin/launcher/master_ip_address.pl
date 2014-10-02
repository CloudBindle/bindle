#! /usr/bin/env perl

use common::sense;
use autodie;

use Data::Dumper;

use Getopt::Long;
use Capture::Tiny ':all';
use FindBin qw($Bin);

use File::Basename qw();

### installing capture tiny : sudo apt-get install libcapture-tiny-perl

### usage
# perl bin/launcher/master_ip_address.pl > name_to_ip_address.pl

my $target_dirs = `ls -l | grep ^d | grep target`;
my @targets_line = split '\n', $target_dirs;

my ($master, %name_to_ip_address);
foreach (@targets_line) {
    $master = (split ' ', $_)[-1];
    if (-d "$Bin/../../$master") {
        my ($stdout, $stderr, $exit) = capture {
            chdir("$Bin/../../$master/master");
            system( "vagrant ssh-config" );
        };

        if ( $stderr ) {
           say STDERR "ERROR: couldn't vagrant ssh-config for $master/master";
        }
        elsif ($stdout) {
           my @config = split '\n', $stdout;
           shift @config;
           my (%vagrant_info, $attribute, $value);
           foreach (@config) {
               ($attribute, $value) = split ' ';
               $vagrant_info{$attribute} = $value;
           }

           if (defined $vagrant_info{HostName}) {
                $name_to_ip_address{$master} = $vagrant_info{HostName};
           }
           else {
               say STDERR "Couldn't determine ip address for $master/master";
           }
        }
    }
    else {
        say STDERR "ERROR: Couldn\'t open directory: $master/master";
    }
}

foreach my $name (keys %name_to_ip_address) {
    say "$name\t$name_to_ip_address{$name}";
}
