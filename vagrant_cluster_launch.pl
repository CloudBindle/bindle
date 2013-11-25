use strict;
use Getopt::Long;
use Data::Dumper;
use JSON;
#use Template;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';

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
my $default_seqware_build_cmd = 'mvn clean install -DskipTests';
my $aws_key = '';
my $aws_secret_key = '';
my $launch_aws = 0;
my $launch_vb = 0;
my $launch_os = 0;
my $launch_cmd = "vagrant up";
my $work_dir = "target";
my $json_config_file = 'vagrant_cluster_launch.json';
my $skip_launch = 0;
# allow the hostname to be specified
my $help = 0;

# check for help
if (scalar(@ARGV) == 0) { $help = 1; }

GetOptions (
  "use-aws" => \$launch_aws,
  "use-virtualbox" => \$launch_vb,
  "use-openstack" => \$launch_os,
  "working-dir=s" => \$work_dir,
  "config-file=s" => \$json_config_file,
  "skip-launch" => \$skip_launch,
  "help" => \$help,
);


# MAIN
if($help) {
  die "USAGE: $0 --use-aws|--use-virtualbox|--use-openstack [--working-dir <working dir path, default is 'target'>] [--config-file <config json file, default is 'vagrant_cluster_launch.json'>] [--skip-launch] [--help]\n";
}

# make the target dir
run("mkdir -p $work_dir");

# config object used for find and replace
my $configs = {};
my $cluster_configs = {};
# Use this temporary object to reconfigure the worker arrays to the format the original script expects
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

print Dumper($cluster_configs);

# dealing with defaults from the config including various SeqWare-specific items
if (!defined($configs->{'SEQWARE_BUILD_CMD'})) { $configs->{'SEQWARE_BUILD_CMD'} = $default_seqware_build_cmd; }

# define the "boxes" used for each provider
# TODO: these are hardcoded and may change
if ($launch_vb) {
  $launch_cmd = "vagrant up";
  $configs->{'BOX'} = "Ubuntu_12.04";
  ####$configs->{'BOX_URL'} = "http://cloud-images.ubuntu.com/vagrant/quantal/current/quantal-server-cloudimg-amd64-vagrant-disk1.box";
  $configs->{'BOX_URL'} = "http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box";
} elsif ($launch_os) {
  $launch_cmd = "vagrant up --provider=openstack";
  $configs->{'BOX'} = "dummy";
  $configs->{'BOX_URL'} = "https://github.com/cloudbau/vagrant-openstack-plugin/raw/master/dummy.box";
} elsif ($launch_aws) {
  $launch_cmd = "vagrant up --provider=aws";
  $configs->{'BOX'} = "dummy";
  $configs->{'BOX_URL'} = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box";
} else {
  die "Don't understand the launcher type to use: AWS, OpenStack, or VirtualBox. Please specify with a --use-* param\n";
}

# process server scripts into single bash script
setup_os_config_scripts($cluster_configs, $work_dir, "os_server_setup.sh");
prepare_files($cluster_configs, $configs, $work_dir);
if (!$skip_launch) {
  # this launches and does first round setup
  launch_instances();
  # this finds IP addresses and does second round of setup
  # FIXME: need a place to process settings files with info taken after launch (e.g. IPs)
  # and this should run via template toolkit since it's much easier to deal with for loops and other complex substitutions
  # TODO: find_cluster_info();
  # TODO: process_and_send_config_template();
  provision_instances();
  print "FINISHED!\n";
}


# SUBS

# uses Vagrant to find the IP and local IP address of the launched machines
sub find_node_info {

  my ($cluster_configs) = @_;

  my $d = {};
  my $node_list = "";

  foreach my $node (sort keys %{$cluster_configs}){
    $node_list .= `cd $work_dir/$node && vagrant status`."\n";
  }
  print "$node_list\n";

  my @t = split /\n/, $node_list;
  foreach my $l (@t) {
    chomp $l;
    my $host_id = "";
    if ($l =~ /(\S+)\s+active/) {
      # openstack
      $host_id = $1;
    } if ($l =~ /(\S+)\s+running/) {
      # aws 
      $host_id = $1;
    }

    print "CLUSTER CONFIG: ".Dumper($cluster_configs)."\n";

    if ($host_id ne "" && defined($cluster_configs->{$host_id})) {

      print "MATCHED HOST ID: $host_id\n";

      my $host_info = `cd $work_dir/$host_id && vagrant ssh-config $host_id`;
      my @h = split /\n/, $host_info;
      my $ip = "";
      my $user = "";
      my $key = "";
      my $port = "";
      foreach my $hl (@h) {
        chomp $hl;
        if ($hl =~ /HostName\s+(\S+)/) { $ip = $1; }
        if ($hl =~ /User\s+(\S+)/) { $user = $1; }
        if ($hl =~ /IdentityFile\s+(\S+)/) { $key = $1; }
        if ($hl =~ /Port\s+(\S+)/) { $port = $1; }
      }
      $d->{$host_id}{ip} = $ip;
      $d->{$host_id}{user} = $user;
      $d->{$host_id}{key} = $key;
      $d->{$host_id}{port} = $port;
      my $pip = `cd $work_dir/$host_id && ssh -p $port -o StrictHostKeyChecking=no -i $key $user\@$ip "/sbin/ifconfig | grep -A 1 eth0 | grep inet"`;
      if ($pip =~ /addr:(\S+)/) { $d->{$host_id}{pip} = $1; }
    }
  }

  return($d);
}

# FIXME: method needs to be broken into individual steps
# FIXME: this is hacking on the configs object which is not good
# this finds all the host IP addresses and then runs the second provisioning on them
sub provision_instances {
  # first, find all the hosts and get their info
  my $hosts = find_node_info($cluster_configs);
  print Dumper($hosts);

  # FIXME: this should be better organized and it's own subroutine 
  # general info
  # this is putting in a variable for the /etc/hosts file
  my $host_str = figure_out_host_str($hosts);
  $configs->{'HOSTS'} = $host_str;
  # FIXME: notice hard-coded to be "master"
  my $master_pip = $hosts->{master}{pip};
  $configs->{'MASTER_PIP'} = $hosts->{master}{pip};
  my $exports = make_exports_str($hosts);
  $configs->{'EXPORTS'} = $exports;
  # DCC specific stuff
  # for the settings.yml
  $configs->{'DCC_PORTAL_SETTINGS_HOST_STR'} = make_dcc_portal_host_string($hosts);
  # for the elasticsearch.yml
  $configs->{'DCC_ES_HOSTS_STR'} = make_dcc_es_host_string($hosts); 

  # now process templates to remote destinations
  run_provision_files($cluster_configs, $hosts);

  # this runs over all hosts and calls the provision scripts in the correct order
  run_provision_script_list($cluster_configs, $hosts);

}

sub make_dcc_es_host_string {
  my ($hosts) = @_;
  my $host_str = "";
  my $first = 1;
  foreach my $host (keys %{$hosts}) {
    my $pip = $hosts->{$host}{pip};
    if ($first) { $first = 0; $host_str .= "\"$pip\""; }
    else { $host_str .= ", \"$pip\""; }
  }
  return($host_str);
}

sub make_dcc_portal_host_string {
  my ($hosts) = @_;
  my $host_str = "";
  foreach my $host (keys %{$hosts}) {
    my $pip = $hosts->{$host}{pip};
    $host_str .= "
    - host: \"$pip\"
      port: 9300";
  }
  return($host_str);
}

# processes and copies files to the specific hosts
sub run_provision_files {
  my ($cluster_configs, $hosts) = @_;
  my @all_threads;
  foreach my $host_name (sort keys %{$hosts}) {
    my $scripts = $cluster_configs->{$host_name}{provision_files};
    my $host = $hosts->{$host_name};
    print "  PROVISIONING FILES TO HOST $host_name\n";
    my $thr = threads->create(\&provision_files_thread, $host_name, $scripts, $host);
    print "  LAUNCHED THREAD PROVISION FILES TO $host_name\n";
    push (@all_threads, $thr);
  }
  # Now wait for the threads to finish; this will block if the thread isn't terminated
  foreach my $thr (@all_threads){
    $thr->join();
  }
}

sub provision_files_thread {
  my ($host_name, $scripts, $host) = @_;
  print "    STARTING THREAD TO PROVISION FILES TO HOST $host_name\n";
  # now run each of these scripts on this host
  foreach my $script (keys %{$scripts}) {
    print "  PROCESSING FILE FOR HOST: $host_name FILE: $script DEST: ".$scripts->{$script}."\n";
    $script =~ /\/([^\/]+)$/;
    my $script_name = $1;
    system("rm /tmp/tmp_$script_name");
    # set the current host before processing file
    setup_os_config_scripts_list($script, "/tmp/tmp_$script_name");
    run("scp -P ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." /tmp/tmp_$script_name ".$host->{user}."@".$host->{ip}.":".$scripts->{$script});
    system("rm /tmp/tmp_$script_name");
  }
}


# this runs all the "second_pass_scripts" in the json for a given host
sub run_provision_script_list {
  my ($cluster_configs, $hosts) = @_;
  my $cont = 1;
  my $curr_cell = 0;

  print Dumper ($cluster_configs);

  while($cont) {
    my @all_threads = ();
    foreach my $host_name (sort keys %{$hosts}) {
      print "  PROVISIONING HOST $host_name\n";
      my $scripts = $cluster_configs->{$host_name}{second_pass_scripts};
      my $host = $hosts->{$host_name};
      if ($curr_cell >= scalar(@{$scripts})) { $cont = 0; }    
      else {
        my $curr_scripts = $scripts->[$curr_cell];
        my $thr = threads->create(\&provision_script_list_thread, $host_name, $host, $curr_scripts, $curr_cell);
        push(@all_threads, $thr);
      }
    }
    foreach my $thr (@all_threads){
      $thr->join();
    }
    $curr_cell++;
  }
}

sub provision_script_list_thread {
  my ($host_name, $host, $curr_scripts, $curr_cell) = @_;
  my $local_configs = dclone $configs;
  # now run each of these scripts on this host
  foreach my $script (@{$curr_scripts}) {
    print "  RUNNING PASS FOR HOST: $host_name ROUND: $curr_cell SCRIPT: $script\n";
    $script =~ /\/([^\/]+)$/;
    my $script_name = $1;
    system("rm /tmp/config_script.sh");
    # set the current host before processing file
    $local_configs->{'HOST'} = $host_name;
    setup_os_config_scripts_list($script, "/tmp/config_script.sh", $local_configs);
    run("scp -P ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." /tmp/config_script.sh ".$host->{user}."@".$host->{ip}.":/tmp/config_script.sh && ssh -p ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo bash /tmp/config_script.sh");
  }
}

# this creates a string to add to /etc/exports
sub make_exports_str {
  my $hosts = shift;
  my $result = "";
  foreach my $host (sort keys %{$hosts}) {
    my $pip = $hosts->{$host}{pip};
    $result .= "
/home $pip(rw,sync,no_root_squash,no_subtree_check)
/datastore $pip(rw,sync,no_root_squash,no_subtree_check)
/usr/tmp/seqware-oozie $pip(rw,sync,no_root_squash,no_subtree_check)
";
  }
  print "EXPORT: $result\n"; 
  return($result);
}

# this creates the /etc/hosts additions
sub figure_out_host_str {
  my ($hosts) = @_;
  my $s = "";
  foreach my $host (sort keys %{$hosts}) {
    $s .= $hosts->{$host}{pip}."  $host\n";
  }
  print "HOSTS: $s\n";
  return($s);
}


# this basically cats files together after doing an autoreplace
sub setup_os_config_scripts_list {
  my ($config_scripts, $output, $configs) = @_;
  my @scripts = split /,/, $config_scripts;
  foreach my $script (@scripts) {
    autoreplace($script, "$output.temp", $configs); 
    run("cat $output.temp >> $output");
    run("rm $output.temp");
  }
}

# this basically cats files together after doing an autoreplace
# that fills in variables from the config part of the JSON
sub setup_os_config_scripts() {
  my ($configs, $output_dir, $output_file) = @_;
  foreach my $host (sort keys %{$configs}) {
    run("mkdir $output_dir/$host");
    foreach my $script (@{$configs->{$host}{first_pass_scripts}}) {
      autoreplace($script, "$output_file.temp");
      run("cat $output_file.temp >> $output_dir/$host/$host\_$output_file");
      run("rm $output_file.temp");
    }
  }
}


sub read_config() {
  my ($file, $config) = @_;
  open IN, "<$file" or die "Can't open your vagrant launch config file: $file\n";
  while (<IN>) {
   chomp;
   next if (/^#/);
   if (/^\s*(\S+)\s*=\s*(.*)$/) {
     $config->{$1} = $2;
     #print "$1 \t $2\n";
   }
  }
  close IN;
}


sub launch_instances {
  my @all_threads;
  foreach my $node (sort keys %{$cluster_configs}) {  
    print "  STARTING THREAD TO LAUNCH INSTANCE FOR NODE $node\n";
    my $thr = threads->create(\&launch_instance, $node);
    push (@all_threads, $thr);
  }
  print "  ALL LAUNCH THREADS STARTED\n";
  # Now wait for the threads to finish; this will block if the thread isn't terminated
  foreach my $thr (@all_threads){
    $thr->join();
  }
  print " ALL LAUNCH THREADS COMPLETED\n";
}

sub launch_instance {
  my $node = $_[0];
  run("cd $work_dir/$node && $launch_cmd");
}

# this assumes the first pass setup script was created per host by setup_os_config_scripts
# FIXME: should remove the non-generic files processed below if possible, notice how there are project-specific file copies below!
sub prepare_files {
  my ($cluster_configs, $configs, $work_dir) = @_;
  # Vagrantfile, the core file used by Vagrant that defines each of our nodes
  setup_vagrantfile("templates/Vagrantfile_start.template", "templates/Vagrantfile_part.template", "templates/Vagrantfile_end.template", $cluster_configs, $configs, "$work_dir");
  foreach my $node (sort keys %{$cluster_configs}) {
    # cron for SeqWare
    autoreplace("templates/status.cron", "$work_dir/$node/status.cron");
    # settings, user data
    copy("templates/settings", "$work_dir/$node/settings");
    copy("templates/user_data.txt", "$work_dir/$node/user_data.txt");
    # script for setting up hadoop hdfs
    copy("templates/setup_hdfs_volumes.pl", "$work_dir/$node/setup_hdfs_volumes.pl");
    copy("templates/hadoop-init-master", "$work_dir/$node/hadoop-init-master");
    copy("templates/hadoop-init-worker", "$work_dir/$node/hadoop-init-worker");
    # hadoop settings files
    # FIXME: right now these config files have "master" hardcoded as the master node
    # FIXME: break out into config driven provisioner
    copy("templates/conf.worker.tar.gz", "$work_dir/$node/conf.worker.tar.gz");
    copy("templates/conf.master.tar.gz", "$work_dir/$node/conf.master.tar.gz");
    # DCC
    # FIXME: break out into config driven provisioner
    autoreplace("templates/DCC/settings.yml", "$work_dir/$node/settings.yml");
    # DCC validator
    copy("templates/dcc_validator/application.conf", "$work_dir/$node/application.conf");
    copy("templates/dcc_validator/init.sh", "$work_dir/$node/init.sh");
    copy("templates/dcc_validator/realm.ini", "$work_dir/$node/realm.ini");
  }
}

# this assumes the first pass script was created per host by setup_os_config_scripts
sub setup_vagrantfile {
  my ($start, $part, $end, $cluster_configs, $configs, $work_dir) = @_;
  print Dumper($cluster_configs);
  print Dumper($configs);
  foreach my $node (sort keys %{$cluster_configs}) {
    my $node_output = "$work_dir/$node/Vagrantfile";
    autoreplace("$start", "$node_output");
    # FIXME: should change this var to something better
    $configs->{custom_hostname} = $node;
    $configs->{OS_FLOATING_IP} = $cluster_configs->{$node}{floatip};
    autoreplace("$part", "$node_output.temp");
    run("cat $node_output.temp >> $node_output");
    run("rm $node_output.temp");
    run("cat $end >> $node_output");
  } 
}

# reads a JSON-based config
sub read_json_config {
  my ($config_file) = @_;
  open IN, "<$config_file" or die;
  my $json_txt = "";
  while(<IN>) { 
    next if (/^\s*#/);
    $json_txt .= $_;
  }
  close IN;
  my $temp_configs = decode_json($json_txt);
  return($temp_configs->{general}, $temp_configs->{node_config});
}

sub autoreplace {
  my ($src, $dest, $localconfigs) = @_;
  unless (defined $localconfigs) {
    $localconfigs = $configs;
  }
  print "AUTOREPLACE: $src $dest\n";
  open IN, "<$src" or die "Can't open input file $src\n";
  open OUT, ">$dest" or die "Can't open output file $dest\n";
  while(<IN>) {
    foreach my $key (sort keys %{$localconfigs}) {
      my $value = $localconfigs->{$key};
      $_ =~ s/%{$key}/$value/g;
    }
    print OUT $_;
  }
  close IN; 
  close OUT;
}

sub replace {
  my ($src, $dest, $from, $to) = @_;
  print "REPLACE: $src, $dest, $from, $to\n";
  open IN, "<$src" or die;
  open OUT, ">$dest" or die;
  while(<IN>) {
    $_ =~ s/$from/$to/g;
    print OUT $_;
  }
  close IN; 
  close OUT;
}

sub copy {
  my ($src, $dest) = @_;
  print "COPYING: $src, $dest\n";
  open IN, "<$src" or die;
  open OUT, ">$dest" or die;
  while(<IN>) {
    print OUT $_;
  }
  close IN;
  close OUT;
}

sub rec_copy {
  my ($src, $dest) = @_;
  print "COPYING REC: $src, $dest\n";
  run("cp -r $src $dest");
}

sub run {
  my ($cmd) = @_;
  print "RUNNING: $cmd\n";
  my $result = system("bash -c '$cmd'");
  if ($result != 0) { die "\nERROR!!! CMD RESULTED IN RETURN VALUE OF $result\n\n"; }
}
