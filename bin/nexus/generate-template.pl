#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use Term::ReadKey;
use Net::OpenSSH;
use Getopt::Euclid;
use Config::Simple;

use launcher;

use Data::Dumper;

my $cfg = new Config::Simple(); 
$cfg->read("config/$ARGV{-config}.cfg");

my %options = (
  user => 'ubuntu',
  key_path => $cfg->param('platform.ssh_key_path'),
  strict_mode => 0,
  master_opts => '-vvv',
  master_opts => [-o => "StrictHostKeyChecking=no"]
);

print 'Username:  ';
my $username = ReadLine();

print 'Type your password:  ';
ReadMode('noecho');
my $password = ReadLine(0);
print "\n";
ReadMode 0;

my $ssh = launcher->connect( $cfg->param('launcher.host'), \%options);



print "Template Generated!!\n";
