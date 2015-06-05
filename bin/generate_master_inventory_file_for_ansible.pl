#! /usr/bin/env perl

use strict;
use warnings;

use feature qw(say);
use autodie;

use FindBin qw($Bin);

### usage
# perl bin/launcher/generate_master_inventory_file_for_ansible.pl <ansible-ssh-host> > inventory

my $ansible_ssh_host = $ARGV[0];

print <<"INVENTORY_HEADER";
[sensu-server]
#sensu-server   ansible_ssh_host=1.2.3.4        ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/root/aws.pem
sensu-server ansible_connection=local ansible_ssh_host=$ansible_ssh_host

[multi-node-master]
#test           ansible_ssh_host=2.3.4.5  ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/root/aws.pem

#[worker]
#worker1                ansible_ssh_host=10.5.74.123    ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/root/aws.pem

[master]
#AWS_single_node           ansible_ssh_host=1.2.3.4  ansible_ssh_user=ubuntu ansible_ssh_private_key_file=/root/aws.pem
INVENTORY_HEADER

my $target_dirs = `ls -l | grep ^d | grep target`;
my @target_lines = split '\n', $target_dirs;
my @targets = map {(split ' ', $_)[-1]} @target_lines;

my ($target_folder, $inventory_file, $line);
foreach (sort { target_number($b) <=> target_number($a) } @targets) {
    $inventory_file = "$Bin/../$_/inventory";
    next unless ( -e $inventory_file);
    $line = `grep ansible_ssh_host $inventory_file`;
    $line =~ s/^master/$_/;
    print $line;
}

sub target_number {
   my ($name) = @_;

   return substr($name,
                 rindex($name, '-'),
                 (length($name) - rindex($name, '-'))
                );
}
