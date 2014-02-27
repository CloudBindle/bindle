#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Net::OpenSSH;
#use Expect;

use File::Basename;
use Getopt::Euclid;
use Config::Simple;

use install::packages;
use install::vagrant;
use install::vagrant::plugin;
use install::seqwareVagrant;

use Data::Dumper;
use common::sense;

my $cfg = new Config::Simple(); 
$cfg->read("config/$ARGV{-config}.cfg");

say 'connecting to launcher';

my $host = $cfg->param('launcher.ip_address');

my $ssh_key_path = $cfg->param('platform.ssh_key_path');
my %options = (
  user => 'ubuntu',
  key_path => $ssh_key_path,
  strict_mode => 0,
 # master_opts => '-vvv'
  master_opts => [-o => "StrictHostKeyChecking=no"]
);

my $ssh = Net::OpenSSH->new( $host, %options);
  $ssh->error and die "Couldn't establish SSH connection: ". $ssh->error;

# add_pem_file($ssh, $options);
# install::packages->all($ssh, $cfg->param('seqwarevagrant.vagrant_file_name'));
# install::vagrant->vagrant($ssh, $cfg->param('seqwarevagramt.vagrant_file_name'));

if ($cfg->param('platform.type') eq 'openstack') {
 # install::vagrant::plugin->openstack($ssh);
} elsif ($cfg->param('platform.type') eq 'aws') {
 # install::vagrant::plugin->aws($ssh);
}

install::seqwareVagrant->all($ssh, $cfg->param('seqwarevagrant.branch'),
                                   $cfg->param('seqwarevagrant.nodes'), 
                                   $cfg->param('seqwarevagrant.scheduler'));

sub add_pem_file {
  my ($self, $ssh, $options) = @_;

  say 'adding ssh pem file';

  my $launcher_key_path = "/home/$options{user}/.ssh/";
  $ssh->scp_put($options{key_path}, $launcher_key_path)
                             or die "scp failed: ". $ssh->error; 

  my $launcher_key_file = $launcher_key_path.basename($options{key_path});
  $ssh->capture('chmod'." 600 $launcher_key_file");
  $ssh->error and die "Couldn't change the permissions to the key file".$ssh->error;
}

say 'it works';
