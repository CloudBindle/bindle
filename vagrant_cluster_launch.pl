use strict;
use Getopt::Long;
use Data::Dumper;
use JSON;
#use Config;
#$Config{useithreads} or die('Recompile Perl with threads to run this program.');

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
# * there's a lot of hacking on the $configs hash in the code, for example defining the master private IP. This is dangerous.

# skips all unit and integration tests
my $default_seqware_build_cmd = 'mvn clean install -DskipTests';
my $seqware_version = 'UNKNOWN';
my $aws_key = '';
my $aws_secret_key = '';
my $launch_aws = 0;
my $launch_vb = 0;
my $launch_os = 0;
my $launch_cmd = "vagrant up";
my $work_dir = "target";
my $json_config_file = 'vagrant_cluster_launch.json';
my $skip_its = 0;
my $skip_launch = 0;
# allow the specification of a specific commit to build and use instead of using the latest from develop
my $git_commit = 0;
# allow the hostname to be specified
my $custom_hostname = "master";

GetOptions (
  "use-aws" => \$launch_aws,
  "use-virtualbox" => \$launch_vb,
  "use-openstack" => \$launch_os,
  "working-dir=s" => \$work_dir,
  "config-file=s" => \$json_config_file,
  "skip-it-tests" => \$skip_its,
  "skip-launch" => \$skip_launch,
  "git-commit=s" => \$git_commit,
  "custom-hostname=s" => \$custom_hostname, # FIXME: I think I broke this, it should probably be removed in favor of the json doc but I assume the master is called master!
);


# MAIN

# figure out the current seqware version based on the most-recently built jar
$seqware_version = find_version();

# make the target dir
run("mkdir $work_dir");

# config object used for find and replace
my $configs = {};
my $cluster_configs = {};
($configs, $cluster_configs) = read_json_config($json_config_file);

# dealing with defaults from the config including various SeqWare-specific items
if (!defined($configs->{'SEQWARE_BUILD_CMD'})) { $configs->{'SEQWARE_BUILD_CMD'} = $default_seqware_build_cmd; }
$configs->{'SEQWARE_VERSION'} = $seqware_version;
# for jenkins, override the branch command if required
if ($git_commit){
  $configs->{'SEQWARE_BRANCH_CMD'} = "git checkout $git_commit";
}
$configs->{'custom_hostname'} = $custom_hostname;

# define the "boxes" used for each provider
# TODO: these are hardcoded and may change
if ($launch_vb) {
  $launch_cmd = "vagrant up";
  $configs->{'BOX'} = "Ubuntu_12.04";
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

# skip the integration tests if specified --skip-its
if ($skip_its) { $configs->{'SEQWARE_IT_CMD'} = ""; }

# process server scripts into single bash script
setup_os_config_scripts($cluster_configs, $work_dir, "os_server_setup.sh");
prepare_files($cluster_configs, $configs, $work_dir);
if (!$skip_launch) {
  # this launches and does first round setup
  launch_instances();
  # this finds IP addresses and does second round of setup
  provision_instances();
}


# SUBS

# uses Vagrant to find the IP and local IP address of the launched machines
sub find_node_info {
  my $d = {};

  my $node_list = `cd $work_dir && vagrant status`;
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
    if ($host_id ne "") {
      my $host_id = $1;
      my $host_info = `cd $work_dir && vagrant ssh-config $host_id`;
      my @h = split /\n/, $host_info;
      my $ip = "";
      my $user = "";
      my $key = "";
      foreach my $hl (@h) {
        chomp $hl;
        if ($hl =~ /HostName\s+(\S+)/) { $ip = $1; }
        if ($hl =~ /User\s+(\S+)/) { $user = $1; }
        if ($hl =~ /IdentityFile\s+(\S+)/) { $key = $1; }
      }
      $d->{$host_id}{ip} = $ip;
      $d->{$host_id}{user} = $user;
      $d->{$host_id}{key} = $key;
      my $pip = `cd $work_dir && ssh -o StrictHostKeyChecking=no -i $key $user\@$ip "/sbin/ifconfig | grep -A 1 eth0 | grep inet"`;
      if ($pip =~ /addr:(\S+)/) { $d->{$host_id}{pip} = $1; }
    }
  }

  return($d);
}

# this finds all the host IP addresses and then runs the second provisioning on them
sub provision_instances {
  # first, find all the hosts and get their info
  my $hosts = find_node_info();
  print Dumper($hosts);

  foreach my $host (keys %{$hosts}) {
    print "PROVISION: $host\n";
    run_provision_script_list($cluster_configs->{$host}, $hosts->{$host}, $hosts);
  }
}

# this runs all the "second_pass_scripts" in the json for a given host
# FIXME: this is hacking on the configs object which is not good
sub run_provision_script_list {
  my ($cluster_config, $host, $hosts) = @_;
  # this is putting in a variable for the /etc/hosts file
  my $host_str = figure_out_host_str($hosts);
  $configs->{'HOSTS'} = $host_str;
  # FIXME: notice hard-coded to be "master"
  my $master_pip = $hosts->{master}{pip};
  $configs->{'MASTER_PIP'} = $hosts->{master}{pip};
  my $exports = make_exports_str($hosts);
  $configs->{'EXPORTS'} = $exports;
  print Dumper (@{$cluster_config->{second_pass_scripts}});
  foreach my $script (@{$cluster_config->{second_pass_scripts}}) {
    print "SECOND PASS SCRIPT: $script\n";
    $script =~ /\/([^\/]+)$/;
    my $script_name = $1;
    system("rm /tmp/config_script.sh");
    setup_os_config_scripts_list($script, "/tmp/config_script.sh");
    run("scp -o StrictHostKeyChecking=no -i ".$host->{key}." /tmp/config_script.sh ".$host->{user}."@".$host->{ip}.":/tmp/config_script.sh && ssh -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo bash /tmp/config_script.sh");
  }
}


# TODO: don't I need to process the script files before sending them over? I'll need to fill in with host info for sure!
sub run_provision_script {
  ########## FIXME
  my ($config_scripts, $host, $hosts) = @_;
  my $host_str = figure_out_host_str($hosts);
  $configs->{'HOSTS'} = $host_str;
  my $master_pip = $hosts->{master}{pip};
  $configs->{'MASTER_PIP'} = $hosts->{master}{pip};
  my $exports = make_exports_str($hosts);
  $configs->{'EXPORTS'} = $exports;
  my @a = split /,/, $config_scripts;
  foreach my $script (@a) {
    $script =~ /\/([^\/]+)$/;
    my $script_name = $1;
    system("rm /tmp/config_script.sh");
    setup_os_config_scripts_list($script, "/tmp/config_script.sh");
    run("scp -o StrictHostKeyChecking=no -i ".$host->{key}." /tmp/config_script.sh ".$host->{user}."@".$host->{ip}.":/tmp/config_script.sh && ssh -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo bash /tmp/config_script.sh");
  }
}

# this creates a string to add to /etc/exports
sub make_exports_str {
  my $hosts = shift;
  my $result = "";
  foreach my $host (keys %{$hosts}) {
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
  foreach my $host (keys %{$hosts}) {
    $s .= $hosts->{$host}{pip}."  $host\n";
  }
  print "HOSTS: $s\n";
  return($s);
}


# this basically cats files together after doing an autoreplace
sub setup_os_config_scripts_list() {
  my ($config_scripts, $output) = @_;
  my @scripts = split /,/, $config_scripts;
  foreach my $script (@scripts) {
    autoreplace($script, "$output.temp"); 
    run("cat $output.temp >> $output");
    run("rm $output.temp");
  }
}

# this basically cats files together after doing an autoreplace
sub setup_os_config_scripts() {
  my ($configs, $output_dir, $output_file) = @_;
  foreach my $host (keys %{$configs}) {
    foreach my $script (@{$configs->{$host}{first_pass_scripts}}) {
      autoreplace($script, "$output_file.temp");
      run("cat $output_file.temp >> $output_dir/$host\_$output_file");
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
  run("cd $work_dir; $launch_cmd");
}

sub find_version {
  my $file = `ls ../seqware-distribution/target/seqware-distribution-*-full.jar | grep -v qe-full`;
  chomp $file;
  if ($file =~ /seqware-distribution-(\S+)-full.jar/) {
   print "SEQWARE VERSION: $1\n";
   return($1);
  } else { 
    die "ERROR: CAN'T FIGURE OUT VERSION FROM FILE: $file\n";
  }
}

# this assumes the first pass setup script was created per host by setup_os_config_scripts
sub prepare_files {
  my ($cluster_configs, $configs, $work_dir) = @_;
  # Vagrantfile, the core file used by Vagrant that defines each of our nodes
  setup_vagrantfile("templates/Vagrantfile_start.template", "templates/Vagrantfile_part.template", "templates/Vagrantfile_end.template", $cluster_configs, $configs, "$work_dir/Vagrantfile");
  # cron for SeqWare
  autoreplace("templates/status.cron", "$work_dir/status.cron");
  # settings, user data
  copy("templates/settings", "$work_dir/settings");
  copy("templates/user_data.txt", "$work_dir/user_data.txt");
  # script for setting up hadoop hdfs
  copy("templates/setup_hdfs_volumes.pl", "$work_dir/setup_hdfs_volumes.pl");
  # hadoop settings files
  # FIXME: break out into config driven provisioniner
  copy("templates/conf.worker.tar.gz", "$work_dir/conf.worker.tar.gz");
  copy("templates/conf.master.tar.gz", "$work_dir/conf.master.tar.gz");
  # DCC
  # FIXME: break out into config driven provisioner
  copy("templates/DCC/settings.yml", "$work_dir/settings.yml");
}

# this assumes the first pass script was created per host by setup_os_config_scripts
sub setup_vagrantfile {
  my ($start, $part, $end, $cluster_configs, $configs, $output) = @_;
  print Dumper($cluster_configs);
  print Dumper($configs);
  autoreplace("$start", "$output");
  foreach my $node (sort keys %{$cluster_configs}) {
    $configs->{custom_hostname} = $node;
    $configs->{OS_FLOATING_IP} = $cluster_configs->{$node}{floatip};
    autoreplace("$part", "$output.temp");
    run("cat $output.temp >> $output");
    run("rm $output.temp");
  } 
  run("cat $end >> $output");
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
  my ($src, $dest) = @_;
  print "AUTOREPLACE: $src $dest\n";
  open IN, "<$src" or die "Can't open input file $src\n";
  open OUT, ">$dest" or die "Can't open output file $dest\n";
  while(<IN>) {
    foreach my $key (keys %{$configs}) {
      my $value = $configs->{$key};
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
  if ($result != 0) { "\nERROR!!! CMD RESULTED IN RETURN VALUE OF $result\n\n"; }
}