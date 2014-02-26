#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Net::OpenSSH;
use Expect;

use File::Basename;
use Getopt::Euclid;
use Regexp::Common qw/net/;
use Config::Simple;

use install::packages;

use Data::Dumper;
use common::sense;

use constant { 
  INSTALL_PACKAGES => 0,
  VAGRANT_FILE_NAME => 'vagrant_1.4.3_x86_64.deb',
  SEQWARE_VAGRANT_BRANCH => 'feature/jmg-unified-pulls'
};

my $cfg = new Config::Simple(); $cfg->read("config/$ARGV{-config}.cfg");



say 'connecting to launcher';

my $host = $cfg->param('launcher.ip_address');

my $ssh_key_path = $cfg->param('platform.ssh_key_path');
my %options = (
  user => 'ubuntu',
  key_path => $ssh_key_path,
  strict_mode => 0,
 # master_opts => [-o => "StrictHostKeyChecking=no"]
);

my $ssh = Net::OpenSSH->new( $host, %options);
  $ssh->error and die "Couldn't establish SSH connection: ". $ssh->error;

# add_pem_file($ssh, $options);
  install::packages->all($ssh, VAGRANT_FILE_NAM, VAGRANT_FILE_NAME);

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
