use strict;
use Getopt::Long;
use Data::Dumper;
use JSON;
#use Template;
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
# * It would be great to use Template::Toolkit for the Vagrantfile and other files we need to do token replacement in
# * add very clear delimiters to each provision step saying what machine is being launched, add DONE to the end

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

# make the target dir
run("mkdir $work_dir");

# config object used for find and replace
my $configs = {};
my $cluster_configs = {};
($configs, $cluster_configs) = read_json_config($json_config_file);

# dealing with defaults from the config including various SeqWare-specific items
if (!defined($configs->{'SEQWARE_BUILD_CMD'})) { $configs->{'SEQWARE_BUILD_CMD'} = $default_seqware_build_cmd; }

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
  # FIXME: need a place to process settings files with info taken after launch (e.g. IPs)
  # and this should run via template toolkit since it's much easier to deal with for loops and other complex substitutions
  # TODO: find_cluster_info();
  # TODO: process_and_send_config_template();
  provision_instances();
}


# SUBS

# uses Vagrant to find the IP and local IP address of the launched machines
sub find_node_info {

  my ($cluster_configs) = @_;

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

    print "CLUSTER CONFIG: ".Dumper($cluster_configs)."\n";

    if ($host_id ne "" && defined($cluster_configs->{$host_id})) {

      print "MATCHED HOST ID: $host_id\n";

      my $host_info = `cd $work_dir && vagrant ssh-config $host_id`;
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
      my $pip = `cd $work_dir && ssh -p $port -o StrictHostKeyChecking=no -i $key $user\@$ip "/sbin/ifconfig | grep -A 1 eth0 | grep inet"`;
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

  foreach my $host_name (sort keys %{$hosts}) {
    print "  PROVISIONING FILES TO HOST $host_name\n";
    my $scripts = $cluster_configs->{$host_name}{provision_files};
    my $host = $hosts->{$host_name};
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
}


# this runs all the "second_pass_scripts" in the json for a given host
sub run_provision_script_list {
  my ($cluster_configs, $hosts) = @_;
  my $cont = 1;
  my $curr_cell = 0;

  print Dumper ($cluster_configs);

  while($cont) {
    foreach my $host_name (sort keys %{$hosts}) {
      print "  PROVISIONING HOST $host_name\n";
      my $scripts = $cluster_configs->{$host_name}{second_pass_scripts};
      my $host = $hosts->{$host_name};
      if ($curr_cell >= scalar(@{$scripts})) { $cont = 0; }    
      else {
        my $curr_scripts = $scripts->[$curr_cell];
        # now run each of these scripts on this host
        foreach my $script (@{$curr_scripts}) {
          print "  RUNNING PASS FOR HOST: $host_name ROUND: $curr_cell SCRIPT: $script\n";
          $script =~ /\/([^\/]+)$/;
          my $script_name = $1;
          system("rm /tmp/config_script.sh");
          # set the current host before processing file
          $configs->{'HOST'} = $host_name;
          setup_os_config_scripts_list($script, "/tmp/config_script.sh");
          run("scp -P ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." /tmp/config_script.sh ".$host->{user}."@".$host->{ip}.":/tmp/config_script.sh && ssh -p ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo bash /tmp/config_script.sh");
        }
      }
    }
    $curr_cell++;
  }
}


# TODO: don't I need to process the script files before sending them over? I'll need to fill in with host info for sure!
sub run_provision_script {
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
  my ($config_scripts, $output) = @_;
  my @scripts = split /,/, $config_scripts;
  foreach my $script (@scripts) {
    autoreplace($script, "$output.temp"); 
    run("cat $output.temp >> $output");
    run("rm $output.temp");
  }
}

# this basically cats files together after doing an autoreplace
# that fills in variables from the config part of the JSON
sub setup_os_config_scripts() {
  my ($configs, $output_dir, $output_file) = @_;
  foreach my $host (sort keys %{$configs}) {
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
  run("cd $work_dir && $launch_cmd");
}

# this assumes the first pass setup script was created per host by setup_os_config_scripts
# FIXME: should remove the non-generic files processed below if possible
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
  # FIXME: right now these config files have "master" hardcoded as the master node
  # FIXME: break out into config driven provisioner
  copy("templates/conf.worker.tar.gz", "$work_dir/conf.worker.tar.gz");
  copy("templates/conf.master.tar.gz", "$work_dir/conf.master.tar.gz");
  # DCC
  # FIXME: break out into config driven provisioner
  autoreplace("templates/DCC/settings.yml", "$work_dir/settings.yml");
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
    foreach my $key (sort keys %{$configs}) {
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
  if ($result != 0) { die "\nERROR!!! CMD RESULTED IN RETURN VALUE OF $result\n\n"; }
}
