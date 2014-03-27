#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Net::OpenSSH;
use Getopt::Euclid;
use Config::Simple;

use launcher;
use install::packages;
use install::vagrant::plugin;
use install::seqwareVagrant;

use Data::Dumper;

my $cfg = new Config::Simple(); 
$cfg->read("config/$ARGV{-config}.cfg");

my %options = (
  user => 'ubuntu',
  key_path => $cfg->param('platform.ssh_key_path'),
  strict_mode => 0,
  #master_opts => '-vvv',
  master_opts => [-o => "StrictHostKeyChecking=no"]
);

my $ssh = launcher->connect( $cfg->param('launcher.host'), \%options);

launcher->add_pem_file($ssh, \%options);
install::packages->all($ssh, $cfg->param('seqwarevagrant.vagrant_file_name'));

if ($cfg->param('platform.type') eq 'openstack') {
  install::vagrant::plugin->openstack($ssh);
} elsif ($cfg->param('platform.type') eq 'aws') {
  install::vagrant::plugin->aws($ssh);
}

install::seqwareVagrant->install($ssh);

install::seqwareVagrant->comment_network($ssh)
                                     if ($cfg->param('platform.network') eq 'none');

install::seqwareVagrant->comment_float_ip($ssh) 
                                   if ($cfg->param('platform.float_ip') eq 'none');

print "Done Provisioning Launcher!!\n";
