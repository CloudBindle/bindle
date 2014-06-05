#!/usr/bin/env perl

use common::sense;
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use Data::Dumper;
use Config::Simple;
use IPC::System::Simple;
use autodie qw(:all);
use Getopt::Long;
use JSON;
#use Template;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';
use Carp::Always;
use cluster::config;
use cluster::provision;
use cluster::setup;
# VARS

# Notes:
# OS_AUTH_URL=https://api.opensciencedatacloud.org:5000/sullivan/v2.0/
# EC2_URL=https://api.opensciencedatacloud.org:8773/sullivan/services/Cloud

# TODO:
# * parallel node launching, each with their own target dir (vs. having Vagrant launch multiple nodes). This will be faster but more work on my part.
# * the box URLs are hardcoded, add them to the config JSON file instead
# * there's a lot of hard-coded (but relative) file paths in this code which could cause problems if we move around or rename template files
# * this is closely tied to SeqWare so we waste some time downloading and building that tool for other projects that use this tool but don't depend on SeqWare
# * related to the above, there are sections of the code below that are SeqWare-specific, Hadoop-specific, and DCC-specific. Consider breaking these out into their own scripts and defining these in the JSON instead. So this core script is a very lean cluster builder script and anything tool-specific (except maybe hadoop or SGE) are out on their own. For now I'm leaving SeqWare items in the below since it causes no harm to other projects using this cluster launcher.
# * or an alternative is just to sync all the config files instead
# * there's a lot of hacking on the $configs hash in the code, for example defining the master private IP. This is dangerous.
# * It would be great to use Template::Toolkit for the Vagrantfile and other files we need to do token replacement in
# * add very clear delimiters to each provision step saying what machine is being launched, add DONE to the end
# * a better way to handle output from multiple VMs run simultaneously... probably just a nice output for each launched instance with the stderr/stdout going to distinct files in the target dir

# skips all unit and integration tests
my $aws_key = '';
my $aws_secret_key = '';
my ($launch_aws, $launch_vb, $launch_os, $launch_vcloud, $skip_launch) = (0,0,0,0,0);
my $launch_cmd = "vagrant up";
my $work_dir = "target";
my ($vb_ram, $vb_cores) = (12000, 2);
my $json_config_file = 'vagrant_cluster_launch.json';
my @ebs_vols = ();
my $default_configs;
my $launch_command = 'vagrant up';
my $cluster_name = 'cluster1';
# check for help
my $help = (scalar @ARGV == 0)? 1 : 0;
my $def_config = 0;
my $json_template_file = "";

GetOptions (
    "use-aws"        => \$launch_aws,
    "use-virtualbox" => \$launch_vb,
    "use-openstack"  => \$launch_os,
    "use-vcloud"     => \$launch_vcloud,
    "working-dir=s" => \$work_dir,
    "config-file=s" => \$json_config_file,
    "launch-cluster=s"  => \$cluster_name,
    "skip-launch"    => \$skip_launch,
    "use-default-config" => \$def_config,
    "vb-ram=i"       => \$vb_ram,
    "vb-cores=i"     => \$vb_cores,
    "aws-ebs=s{1,}"  => \@ebs_vols,
    "help"           => \$help,
);

# MAIN
if($help) {
  die "USAGE: $0 --use-aws|--use-virtualbox|--use-openstack|--use-vcloud [--working-dir <working dir path, default is 'target'>] [--config-file <config json file, default is 'vagrant_cluster_launch.json'>] [--vb-ram <the RAM (in MB) to use with VirtualBox only, HelloWorld expects at least 9G, default is 12G>] [--vb-cores <the number of cores to use with Virtual box only, default is 2>] [--aws-ebs <EBS vol size in MB, space delimited>] [--skip-launch] [--help]\n";
}

$launch_command .= cluster::config->set_launch_command($launch_aws, $launch_os, $launch_vcloud);

# config object used for find and replace
my $configs = {};
my $cluster_configs = {};

#used for reading in from the .cfg files
if ($def_config){
  #reconfigures the worker arrays to the format the original script expects
  #also reads in all the default configurations for the appropriate platfrom 
  #from the .cfg file in the config folder
  ($configs, $cluster_configs, $work_dir, $json_template_file) = cluster::config->read_default_configs($cluster_name, $launch_vcloud, $launch_aws, $launch_os, $launch_vb);
  
  system("cp $json_template_file $json_config_file");

}
else{
  my $temp_cluster_configs = ();
  ($configs, $temp_cluster_configs) = read_json_config($json_config_file);

  foreach my $node_config (@{$temp_cluster_configs}){
    my @names = @{$node_config->{'name'}};
    for (0 .. $#names){
      my $node_config_copy = dclone $node_config;
      print @{$node_config_copy->{'floatip'}}[$_]."\n";
      delete $node_config_copy->{'floatip'};
      $node_config_copy->{'floatip'} = @{$node_config->{'floatip'}}[$_];
      $cluster_configs->{$names[$_]} = $node_config_copy;
    }
  }
  # define the "boxes" used for each provider
  # TODO: these are hardcoded and may change
  # you can override for VirtualBox only via the json config
  # you can find boxes listed at http://www.vagrantbox.es/
  if ($launch_vb) {
    $launch_cmd = "vagrant up";

    # Allow a custom box to be specified
    if (!defined($configs->{'BOX'})) { $configs->{'BOX'} = "Ubuntu_12.04"; }
    if (!defined($configs->{'BOX_URL'})) { $configs->{'BOX_URL'} = "http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box"; }
  } elsif ($launch_os) {
    $launch_cmd = "vagrant up --provider=openstack";
    $configs->{'BOX'} = "dummy";
    $configs->{'BOX_URL'} = "https://github.com/cloudbau/vagrant-openstack-plugin/raw/master/dummy.box";
  } elsif ($launch_aws) {
    $launch_cmd = "vagrant up --provider=aws";
    $configs->{'BOX'} = "dummy";
    $configs->{'BOX_URL'} = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box";
  } elsif ($launch_vcloud) {
    $launch_cmd = "vagrant up --provider=vcloud";
    $configs->{'BOX'} = "pancancer_1";
    $configs->{'BOX_URL'} = "https://raw.github.com/SeqWare/vagrant/feature/jmg-vagrant-vcloud/vcloudTest/ubuntu_12_04.box"
  } else {
    die "Don't understand the launcher type to use: AWS, OpenStack, VirtualBox, or vCloud. Please specify with a --use-* param\n";
  }
}


# dealing with defaults from the config including various SeqWare-specific items
my $default_seqware_build_cmd = 'mvn clean install -DskipTests';
$configs->{'SEQWARE_BUILD_CMD'} //= $default_seqware_build_cmd; 
$configs->{'MAVEN_MIRROR'} //= ""; 

# process server scripts into single bash script
# this basically cats files together after doing an autoreplace
# that fills in variables from the config part of the JSON
cluster::setup->setup_os_config_scripts($cluster_configs, $work_dir, "os_server_setup.sh");

# this assumes the first pass setup script was created per host by setup_os_config_scripts
# FIXME: should remove the non-generic files processed (bin/cluster/setup.pm) if possible, notice how there are project-specific file copies!
cluster::setup->prepare_files($cluster_configs, $configs, $work_dir, $vb_ram, $vb_cores, @ebs_vols);

launch_instances($cluster_configs) unless ($skip_launch);
sleep 100;

# FIXME: this is hacking on the configs object which is not good
# this finds all the host IP addresses and then runs the second provisioning on them
cluster::provision->provision_instances($configs, $cluster_configs, $work_dir) unless ($skip_launch);
say "FINISHED";

sub launch_instances {
    my @threads;
    foreach my $node (sort keys %{$cluster_configs}) {  
        say "  STARTING THREAD TO LAUNCH INSTANCE FOR NODE $node";
        my $thr = threads->create(\&launch_instance, $node);
        push (@threads, $thr);
        # attempt to prevent RequestLimitExceeded on Amazon by sleeping between thread launch 
        # http://docs.aws.amazon.com/AWSEC2/latest/APIReference/api-error-codes.html
        sleep 30;
    }
    print "  ALL LAUNCH THREADS STARTED\n";
    # Now wait for the threads to finish; this will block if the thread isn't terminated
    foreach my $thr (@threads){
        $thr->join();
    }
    print " ALL LAUNCH THREADS COMPLETED\n";
}

sub launch_instance {
    my $node = $_[0];
    
    run("cd $work_dir/$node && $launch_command", $node);
}

sub run {
    my ($cmd, $hostname) = @_;

    my $outputfile = "";
    # by default pipe to /dev/null if no hostname is specified, this 
    # will prevent a default.log file from being a mixture of different thread's output
    my $final_cmd = "bash -c '$cmd' > /dev/null 2> /dev/null";
    # only output to host-specific log if defined
    if (defined($hostname)){
        $outputfile = "$work_dir/$hostname.log";
        $final_cmd = "bash -c '$cmd' >> $outputfile 2>&1";
    } 

    say "RUNNING: $final_cmd";
    if ($final_cmd =~ /vagrant up/) {
        no autodie qw(system);
        system($final_cmd);
        say 'launched machine!';
    }
    else {
        system($final_cmd);
    }
}
