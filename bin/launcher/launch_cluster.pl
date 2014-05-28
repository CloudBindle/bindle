#!/usr/bin/env perl

use common::sense;
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
my ($launch_aws, $launch_vb, $launch_os, $launch_vcloud, $skip_launch) = (0,0,0,0,0);
my $launch_cmd = "vagrant up";
my $work_dir = "target";
my ($vb_ram, $vb_cores) = (12000, 2);
my @ebs_vols = ();
my $default_configs;
my $launch_command = 'vagrant up';
my $cluster_name = 'cluster1';
# check for help
my $help = (scalar @ARGV == 0)? 1 : 0;

GetOptions (
    "use-aws"        => \$launch_aws,
    "use-virtualbox" => \$launch_vb,
    "use-openstack"  => \$launch_os,
    "use-vcloud"     => \$launch_vcloud,
    "use-cluster=s"  => \$cluster_name,
    "skip-launch"    => \$skip_launch,
    "vb-ram=i"       => \$vb_ram,
    "vb-cores=i"     => \$vb_cores,
    "aws-ebs=s{1,}"  => \@ebs_vols,
    "help"           => \$help,
);

# MAIN
if($help) {
  die "USAGE: $0 --use-aws|--use-virtualbox|--use-openstack|--use-vcloud [--working-dir <working dir path, default is 'target'>] [--config-file <config json file, default is 'vagrant_cluster_launch.json'>] [--vb-ram <the RAM (in MB) to use with VirtualBox only, HelloWorld expects at least 9G, default is 12G>] [--vb-cores <the number of cores to use with Virtual box only, default is 2>] [--aws-ebs <EBS vol size in MB, space delimited>] [--skip-launch] [--help]\n";
}

if ($launch_aws){
  $default_configs = new Config::Simple('config/aws.cfg');
  $launch_command .= ' --provider=aws';
}
elsif ($launch_os){ 
  $default_configs = new Config::Simple('config/os.cfg');
  $launch_command .= ' --provider=openstack';
}
elsif ($launch_vcloud){
  $default_configs = new Config::Simple('config/vcloud.cfg');
  $launch_command .= ' --provider=vcloud';
}
elsif ($launch_vb) {
  $default_configs = new Config::Simple('config/vb.cfg');
}

$work_dir = make_target_directory($cluster_name,$default_configs, $work_dir);

sub make_target_directory {
   my ($cluster_name,$default_configs, $work_dir) = @_;
   
   $work_dir = $default_configs->param("$cluster_name.target_directory");
   run("mkdir -p $work_dir");
   
   return $work_dir;
}

# config object used for find and replace
my $configs = {};
my $cluster_configs = {};
#reconfigures the worker arrays to the format the original script expects
#also reads in all the default configurations for the appropriate platfrom 
#from the .cfg file in the config folder
($configs, $cluster_configs) = read_default_configs($default_configs);

# dealing with defaults from the config including various SeqWare-specific items
$configs->{'SEQWARE_BUILD_CMD'} //= $default_seqware_build_cmd; 
$configs->{'MAVEN_MIRROR'} //= ""; 

# process server scripts into single bash script
setup_os_config_scripts($cluster_configs, $work_dir, "os_server_setup.sh");

prepare_files($cluster_configs, $configs, $work_dir);

launch_and_provision_vms($cluster_configs) unless ($skip_launch);

say "FINISHED";

sub launch_and_provision_vms {
    my ($cluster_config) = @_;

    launch_instances($cluster_config);

    sleep 100;
    provision_instances($cluster_config);
  
    return;
}

sub find_cluster_info {
    my ($cluster_config) = @_;

    my (%cluster_info, @node_status, $vagrant_status);
    foreach my $node (sort keys %{$cluster_config}) {
        $vagrant_status = `cd $work_dir/$node && vagrant status`.'\n';
        chomp $vagrant_status;
        find_node_info(\%cluster_info, $vagrant_status);
    #    push @node_status, $vagrant_status;
    }

    return \%cluster_info;
}

sub get_host_id_from_vagrant_status {
    my ($status) = @_;

    if ($status =~ /Current machine states:\s+(\S+)\s+(active|running)/) { # openstack and vcloud ar running, aws is running
        return $1;
    } 
    die 'Was unable to get node infomation';
}

sub find_node_info {
    my ($cluster_info, $vagrant_status) = @_;

    my $host_id = get_host_id_from_vagrant_status($vagrant_status);

    if ($host_id ne "" && defined($cluster_configs->{$host_id})) {
       $cluster_info->{$host_id} = host_information($work_dir, $host_id);
    }
 
}


sub host_information {
    my ($sork_dir, $host_id) = @_;
  
    my $host_info = `cd $work_dir/$host_id && vagrant ssh-config $host_id`;
    my @hosts_info = split "\n", $host_info;

    my %host;
    foreach my $hl (@hosts_info) {
        chomp $hl;

        if ($hl =~ /HostName\s+(\S+)/) { 
            $host{ip} = $1;
        }
        elsif ($hl =~ /User\s+(\S+)/) { 
            $host{user} = $1;
        }
        elsif ($hl =~ /IdentityFile\s+(\S+)/) { 
           $host{key} = $1;
        }
        elsif ($hl =~ /Port\s+(\S+)/) {
           $host{port} = $1;
        }
    }

    my $pip = get_pip_id($work_dir, $host_id, \%host);
    $host{pip} = $pip if ($pip); 

    return \%host; 
}

sub get_pip_id {
    my ($work_dir, $host_id, $host) = @_;
 
    my $pip = `cd $work_dir/$host_id && ssh -p $host->{port} -o StrictHostKeyChecking=no -i $host->{key} $host->{user}\@$host->{ip} \"/sbin/ifconfig | grep -A 1 eth0 | grep inet\"`;
 
    return ($pip =~ /addr:(\S+)/)? $1: 0;
}

# FIXME: method needs to be broken into individual steps
# FIXME: this is hacking on the configs object which is not good
# this finds all the host IP addresses and then runs the second provisioning on them
sub provision_instances {
    my ($cluster_configs) = @_;
    # first, find all the hosts and get their info
    my $hosts = find_cluster_info($cluster_configs);

    # FIXME: this should be better organized and it's own subroutine 
    # general info
    # this is putting in a variable for the /etc/hosts file
    $configs->{HOSTS} =  figure_out_host_str($hosts);
    $configs->{SGE_HOSTS} = figure_out_sge_host_str($hosts);

    # FIXME: notice hard-coded to be "master"
    my $master_pip = $hosts->{master}{pip};
    $configs->{MASTER_PIP} = $hosts->{master}{pip};
    $configs->{EXPORTS} = make_exports_str($hosts);

    # DCC specific stuff
    # for the settings.yml
    $configs->{DCC_PORTAL_SETTINGS_HOST_STR} = make_dcc_portal_host_string($hosts);

    # for the elasticsearch.yml
    $configs->{DCC_ES_HOSTS_STR} = make_dcc_es_host_string($hosts); 
  
    # now process templates to remote destinations
    run_provision_files($cluster_configs, $hosts);
  
    # this runs over all hosts and calls the provision scripts in the correct order
    run_provision_script_list($cluster_configs, $hosts);

    return;  
}

sub make_dcc_es_host_string {
    my ($hosts) = @_;

    my @host_ids;
    foreach my $host (keys %{$hosts}) {
        push @host_ids, $hosts->{$host}{pip};
    }
 
    return '"'.join('","', @host_ids).'"';
}

sub make_dcc_portal_host_string {
    my ($hosts) = @_;
    my $host_str = "";
    foreach my $host (keys %{$hosts}) {
        my $pip = $hosts->{$host}{pip};
        $host_str .= "- host: \"$pip\" port: 9300";
    }

    return $host_str;
}

# processes and copies files to the specific hosts
sub run_provision_files {
    my ($cluster_configs, $hosts) = @_;

    my @threads;
    foreach my $host_name (sort keys %{$hosts}) {
        my $scripts = $cluster_configs->{$host_name}{provision_files};
        my $host = $hosts->{$host_name};
        say "  PROVISIONING FILES TO HOST $host_name"; 
        #run("rsync -e \"ssh -i $host->{key}\" -avz $work_dir/$host_name/ $host->{user}".'@'."$host->{ip}:/vagrant/");
        push @threads, threads->create(\&provision_files_thread,
                                         $host_name, $scripts, $host);
        say "  LAUNCHED THREAD PROVISION FILES TO $host_name";
    }

    # Now wait for the threads to finish; this will block if the thread isn't terminated
    foreach my $thread (@threads){
        $thread->join();
    }

}

sub provision_files_thread {
    my ($host_name, $scripts, $host) = @_;

    say "    STARTING THREAD TO PROVISION FILES TO HOST $host_name";
    # now run each of these scripts on this host
    foreach my $script (keys %{$scripts}) {
        say "  PROCESSING FILE FOR HOST: $host_name FILE: $script DEST: ".$scripts->{$script};
        $script =~ /\/([^\/]+)$/;
        my $script_name = $1;
        system("mkdir -p $work_dir/scripts/");
        my $tmp_script_name = "$work_dir/scripts/tmp_$host_name\_$script_name";

        # set the current host before processing file
        setup_os_config_scripts_list($script, $tmp_script_name);
        run("scp -P ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." $tmp_script_name ".$host->{user}."@".$host->{ip}.":".$scripts->{$script}, $host_name);
        system("rm $tmp_script_name");
    }
    
}


# this runs all the "second_pass_scripts" in the json for a given host
sub run_provision_script_list {
  my ($cluster_configs, $hosts) = @_;
  my $cont = 1;
  my $curr_cell = 0;

  while($cont) {
    my @threads = ();
    foreach my $host_name (sort keys %{$hosts}) {
      say "  PROVISIONING HOST $host_name FOR PASS $curr_cell";
      my $scripts = $cluster_configs->{$host_name}{second_pass_scripts};
      my $host = $hosts->{$host_name};
      if ($curr_cell >= scalar(@{$scripts})) { 
          $cont = 0;
      }    
      else {
          my $curr_scripts = $scripts->[$curr_cell];
          push @threads, threads->create(\&provision_script_list_thread, $host_name, $host, $curr_scripts, $curr_cell);
      }
    }
    foreach my $thr (@threads){
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
        system("mkdir -p $work_dir/scripts/");
        # set the current host before processing file
        $local_configs->{'HOST'} = $host_name;
        setup_os_config_scripts_list($script, "$work_dir/scripts/config_script.$host_name\_$script_name", $local_configs);
        run("ssh -p ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo mkdir -p /vagrant_scripts", $host_name);
        run("ssh -p ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo chmod a+rwx /vagrant_scripts", $host_name);
        run("scp -P ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." $work_dir/scripts/config_script.$host_name\_$script_name ".$host->{user}."@".$host->{ip}.":/vagrant_scripts/config_script.$host_name\_$script_name && ssh -p ".$host->{port}." -o StrictHostKeyChecking=no -i ".$host->{key}." ".$host->{user}."@".$host->{ip}." sudo bash -i /vagrant_scripts/config_script.$host_name\_$script_name", $host_name);
    }
}

# this creates a string to add to /etc/exports
sub make_exports_str {
    my ($hosts) = @_;

    my $result = "";
    foreach my $host (sort keys %{$hosts}) {
        my $pip = $hosts->{$host}{pip};
        $result .= "/home $pip(rw,sync,no_root_squash,no_subtree_check)
           /mnt/home $pip(rw,sync,no_root_squash,no_subtree_check)
           /mnt/datastore $pip(rw,sync,no_root_squash,no_subtree_check)
           /mnt/seqware-oozie $pip(rw,sync,no_root_squash,no_subtree_check)";
    }

    return $result;
}

# this creates the /etc/hosts additions
sub figure_out_host_str {
    my ($hosts) = @_;
  
    my $hosts_str = "";
    foreach my $host (sort keys %{$hosts}) {
      $hosts_str .= $hosts->{$host}{pip}."  $host\n";
    }

    return $hosts_str;
}

# this creates the sge host list
sub figure_out_sge_host_str {
    my ($hosts) = @_;

    my $hosts_str = "";
    foreach my $host (sort keys %{$hosts}) {
        $hosts_str .= " $host";
    }

    return $hosts_str;
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
sub setup_os_config_scripts {
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
  
    open my $in, '<', $file;
  
    while (<$in>) {
        chomp;
        next if (/^#/);
        if (/^\s*(\S+)\s*=\s*(.*)$/) {
            $config->{$1} = $2;
            #print "$1 \t $2\n";
        }
    }
  
    close $in;
}


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

# this assumes the first pass setup script was created per host by setup_os_config_scripts
# FIXME: should remove the non-generic files processed below if possible, notice how there are project-specific file copies below!
sub prepare_files {
    my ($cluster_configs, $configs, $work_dir) = @_;

    # Vagrantfile, the core file used by Vagrant that defines each of our nodes
    setup_vagrantfile("templates/Vagrantfile_start.template", 
                      "templates/Vagrantfile_part.template", 
                      "templates/Vagrantfile_end.template", 
                      $cluster_configs, $configs, "$work_dir", $vb_ram, $vb_cores);

    foreach my $node (sort keys %{$cluster_configs}) {
        # cron for SeqWare
        autoreplace("templates/status.cron", "$work_dir/$node/status.cron");
        # various files used for SeqWare when installed and not built from source
        autoreplace("templates/seqware/seqware-webservice.xml", "$work_dir/$node/seqware-webservice.xml");
        autoreplace("templates/seqware/seqware-portal.xml", "$work_dir/$node/seqware-portal.xml");
        # settings, user data
        copy("templates/settings", "$work_dir/$node/settings");
        copy("templates/user_data.txt", "$work_dir/$node/user_data.txt");
        # script for setting up hadoop hdfs
        copy("templates/setup_hdfs_volumes.pl", "$work_dir/$node/setup_hdfs_volumes.pl");
        copy("templates/setup_volumes.pl", "$work_dir/$node/setup_volumes.pl");
        copy("templates/setup_gluster_peers.pl", "$work_dir/$node/setup_gluster_peers.pl");
        copy("templates/setup_gluster_service.pl", "$work_dir/$node/setup_gluster_service.pl");
        copy("templates/setup_gluster_volumes.pl", "$work_dir/$node/setup_gluster_volumes.pl");
        # these are used for when the box is rebooted, it setups the /etc/hosts file for example
        replace("templates/hadoop-init-master", "$work_dir/$node/hadoop-init-master", '%{HOST}', $node);
        replace("templates/hadoop-init-worker", "$work_dir/$node/hadoop-init-worker", '%{HOST}', $node);
        # this is used for the master SGE node to recover when the system is rebooted
        # NOTE: it's not easy to get this same thing to work with reboot for whole clusters
        replace("templates/sge-init-master", "$work_dir/$node/sge-init-master", '%{HOST}', $node);
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
    }
}

# this assumes the first pass script was created per host by setup_os_config_scripts
sub setup_vagrantfile {
    my ($start, $part, $end, $cluster_configs, $configs, $work_dir, $ram, $cores) = @_;

    foreach my $node (sort keys %{$cluster_configs}) {
        $configs->{custom_hostname} = $node;
        $configs->{VB_CORES} = $cores;
        $configs->{VB_RAM} = $ram;
        $configs->{OS_FLOATING_IP} = $cluster_configs->{$node}{floatip};
        if (not exists $configs->{AWS_REGION}){
    	    $configs->{AWS_REGION} = "us-east-1";
        }
        if (not exists $configs->{AWS_ZONE} or $configs->{AWS_ZONE} eq "nil" ){
    	    $configs->{AWS_ZONE} = "nil";
        }
        elsif ($configs->{AWS_ZONE} !~ /^"\S+"$/) { 
            $configs->{AWS_ZONE} = "\"$configs->{AWS_ZONE}\"";
        }

        $configs->{AWS_EBS_VOLS} = "";
        if (scalar @ebs_vols > 0){
            $configs->{AWS_EBS_VOLS} .= "aws.block_device_mapping = [";
            # starts at "f=102"
            my $count = 102;
            foreach my $size (@ebs_vols){
                my $current_name = chr $count;
    	        $configs->{AWS_EBS_VOLS} .= "{'DeviceName' => \"/dev/sd$current_name\", 'VirtualName' => \"block_storage\", 'Ebs.VolumeSize' => $size, 'Ebs.DeleteOnTermination' => true},";
    	        $count++;
    	    }
            chop $configs->{AWS_EBS_VOLS};
    	    $configs->{AWS_EBS_VOLS} .= "]";
        }
        my $node_output = "$work_dir/$node/Vagrantfile";
        autoreplace("$start", "$node_output");
        # FIXME: should change this var to something better
        autoreplace("$part", "$node_output.temp");
        run("cat $node_output.temp >> $node_output");
        run("rm $node_output.temp");
        run("cat $end >> $node_output");
        # hack to deal with empty network/floatIP
        my $full_output = `cat $node_output`;
        # HACK: this is a hack because we don't properly templatize the Vagrantfile... I'm doing this to eliminate empty os.network and os.floating_ip which cause problems on various OpenStack clouds
        $full_output =~ s/os.network = "<FILLMEIN>"//;
        $full_output =~ s/os.network = ""//;
        $full_output =~ s/os.floating_ip = "<FILLMEIN>"//;
        $full_output =~ s/os.floating_ip = ""//;
    
        open my $vout, '>', $node_output;
        print $vout $full_output;
        close $vout;
    }
}

# reads a JSON-based config
sub read_default_configs {
  my ($default_configs) = @_;
  my $config_file = $default_configs->param("$cluster_name.json_template_file_path");
  open IN, "<$config_file" or die "No template JSON file detected in this directory!";
  my $json_txt = "";
  
  while(<IN>) { 
    next if (/^\s*#/);
    $json_txt .= $_;
  }
  close IN;
  
  my $temp_configs = decode_json($json_txt);
  my $general_config = extract_general_config($temp_configs->{general});
  my ($temp_cluster_configs, $cluster_configs) = {};
  
  if ($launch_aws || $launch_os || $launch_vcloud){
    $temp_cluster_configs = extract_node_config($temp_configs->{node_config});
  }
  elsif ($launch_vb){ 
    $temp_cluster_configs = $temp_configs->{node_config}; 
    $general_config->{'BOX'} //= "Ubuntu_12.04"; 
    $general_config->{'BOX_URL'} //= "http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box";
  }
  else{ 
    die "Don't understand the launcher type to use: AWS, OpenStack, VirtualBox, or vCloud. Please specify with a --use-* param"; 
  }

  foreach my $node_config (@{$temp_cluster_configs}){
    my @names = @{$node_config->{'name'}};
    for (0 .. $#names){
      my $node_config_copy = dclone $node_config;
      delete $node_config_copy->{'floatip'};
      $node_config_copy->{'floatip'} = @{$node_config->{'floatip'}}[$_];
      $cluster_configs->{$names[$_]} = $node_config_copy;
    }
  }
  
  return($general_config, $cluster_configs);
}

#extracts the floating IP's from the .cfg file
sub extract_node_config {

  my ($temp_cluster_configs) = @_;
  my (@worker_nodes, @float_ips, @os_float_ips) = ();
  my $number_of_nodes = $default_configs->param("$cluster_name.number_of_nodes");
  
  if ($launch_os){
    @os_float_ips = $default_configs->param("$cluster_name.floating_ips");
    my @master_float_ip = $os_float_ips[0];
    $temp_cluster_configs->[0]->{floatip} = \@master_float_ip;
  }
  
  for (my $i = 1; $i < $number_of_nodes; $i++){
    push(@worker_nodes,'worker'.$i);
    if ($launch_os){
      push(@float_ips, $os_float_ips[$i]);
    }
    else{
      push(@float_ips, '<FILLMEIN>');
    }
  }
  
  $temp_cluster_configs->[1]->{name} = \@worker_nodes;
  $temp_cluster_configs->[1]->{floatip} = \@float_ips;
  return $temp_cluster_configs;
}

#reads a .cfg file and extracts the required platform configurations
sub extract_general_config {
  my ($general_config) = @_;
  my $selected_platform = uc $default_configs->param('platform.type');
  
  foreach my $key (sort keys $default_configs->param(-block=>'platform')) {
    # define the "boxes" used for each provider
    # These may be changed in the config file
    # you can override for VirtualBox only via the json config
    # you can find boxes listed at http://www.vagrantbox.es/
    if($key =~ /box/){
      $general_config->{uc $key} = $default_configs->param('platform.'.$key);
    }
    else{
      $general_config->{$selected_platform.'_'.(uc $key)} = $default_configs->param('platform.'.$key);
    }
  }
  
  my $pem_file = $default_configs->param('platform.ssh_key_name');
  if ($launch_vcloud){
    $general_config->{'VCLOUD_USER_NAME'} = $default_configs->param('platform.ssh_username');
  }
  else{
    $general_config->{$selected_platform.'_SSH_PEM_FILE'} = "~/.ssh/".$pem_file.".pem";
  }
  
  $general_config->{'SSH_PRIVATE_KEY_PATH'} = "~/.ssh/".$pem_file.".pem";
  
  return $general_config;
}

sub autoreplace {
    my ($src, $dest, $local_configs) = @_;

    $local_configs //= $configs;

    say "AUTOREPLACE: $src $dest";

    open my $in, '<', $src;
    open my $out, '>', $dest;

    while(<$in>) {
        foreach my $key (sort keys %{$local_configs}) {
            my $value = $local_configs->{$key};
            $_ =~ s/%{$key}/$value/g;
        }
        print $out $_;
    }

    close $in, $out;
}

sub replace {
    my ($src, $dest, $from, $to) = @_;
  
    say "REPLACE: $src, $dest, $from, $to";

    open my $in, '<', $src;
    open my $out, '>', $dest;
    while(<$in>) {
        $_ =~ s/$from/$to/g;
        print $out $_;
    }
    close $in, $out;
}

sub copy {
    my ($src, $dest) = @_;

    say "COPYING: $src, $dest";

    open my $in, '<', $src;
    open my $out, '>', $dest;
    while(<$in>) {
        print $out $_;
    }
    close $in, $out;
}

sub rec_copy {
    my ($src, $dest) = @_;

    say "COPYING REC: $src, $dest";

    run("cp -r $src $dest");
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
