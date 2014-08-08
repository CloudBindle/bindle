package cluster::config;

use Config::Simple;
use common::sense;
use Carp::Always;
use autodie qw(:all);
use JSON;
use Config;
use Storable 'dclone';
use Data::Dumper;
use File::Spec;
use Cwd 'abs_path';
#reads in all the data written to the appropriate config file located at config/
#and constructs an object in the form of configs and default_configs to match
#the format the original script expects it to be in
sub read_default_configs {
  my ($class, $cluster_name, $launch_vcloud, $launch_aws, $launch_os, $launch_vb) = @_;
  my $default_configs = new Config::Simple();
  my $abs_path = "";
  # gets the absolute path (ex. /home/ubuntu/.bindle/<platform>.cfg)
  if ($launch_aws){
      $abs_path = `readlink -f ~/.bindle/aws.cfg`;
  }
  elsif ($launch_os){ 
      $abs_path = `readlink -f ~/.bindle/os.cfg`;
  }
  elsif ($launch_vcloud){
      $abs_path = `readlink -f ~/.bindle/os.cfg`;
  }
  elsif ($launch_vb) {
    $abs_path = `readlink -f ~/.bindle/vb.cfg`;
  }
  $abs_path = (split(/\n/,$abs_path))[0];
  my $rel_path = File::Spec->abs2rel($abs_path,'.');  
  
  # upgrade or copy the configs over to ~/.bindle/ if it doesn't exist
  if (-e $abs_path and not upgrade_outdated_configs($abs_path,$rel_path)){
    $default_configs->read($rel_path) or die $default_configs->error();
  }else{
    copy_over_config_templates();
  }
  
  my $config_file = $default_configs->param("$cluster_name.json_template_file_path");
  my $work_dir = make_target_directory($cluster_name,$default_configs);
  my $temp_configs = read_json_config($config_file);
  my $general_config = extract_general_config($temp_configs->{general},$default_configs,$launch_vcloud);
  my ($temp_cluster_configs, $cluster_configs) = {};
  
  if ($launch_aws || $launch_os || $launch_vcloud){
    $temp_cluster_configs = extract_node_config($temp_configs->{node_config},$default_configs,$launch_os, $cluster_name);
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
  
  return($general_config, $cluster_configs, $work_dir,$config_file);
}

#reads in the json file and gets rid of all the commented lines
sub read_json_config {
  my ($config_file) = @_;
  open IN, '<', $config_file or die "No template JSON file detected in this directory!";
  my $json_txt = "";

  while(<IN>) {
    next if (/^\s*#/);
    $json_txt .= $_;
  }
  close IN;

  my $temp_configs = decode_json($json_txt);
  return $temp_configs;
}

#this extracts all the information needed to set up the particular cluster
#that is, it extracts floating_ips and the number of nodes it will have
sub extract_node_config {
  my ($temp_cluster_configs, $default_configs,$launch_os, $cluster_name) = @_;

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

#extracts all the platform related information from the config file
sub extract_general_config {
  my ($general_config, $default_configs,$launch_vcloud) = @_;
  my $selected_platform = uc $default_configs->param('platform.type');
  
  foreach my $key (sort keys $default_configs->param(-block=>'platform')) {
    # define the "boxes" used for each provider
    # These may be changed in the config file
    # you can override for VirtualBox only via the json config
    # you can find boxes listed at http://www.vagrantbox.es/
    if($key =~ /box|gluster/){
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

  $general_config->{$selected_platform.'_SSH_PEM_FILE'} = "~/.ssh/".$pem_file.".pem";
  $general_config->{'SSH_PRIVATE_KEY_PATH'} = "~/.ssh/".$pem_file.".pem";
  

  
  return $general_config;
}

#reads in the target_directory specified in the config file and makes a folder
sub make_target_directory {
   my ($cluster_name,$default_configs) = @_;
   
   my $work_dir = $default_configs->param("$cluster_name.target_directory");
   run($work_dir,"mkdir -p $work_dir");
   
   return $work_dir;
}

sub run {
    my ($work_dir,$cmd, $hostname) = @_;

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

#adds on to the launch_command for vagrant according to the specified platform
sub set_launch_command {
  my ($class, $launch_aws, $launch_os, $launch_vcloud) = @_;
  my $launch_command;
  if ($launch_aws){
    $launch_command = ' --provider=aws';
  }
  elsif ($launch_os){ 
    $launch_command = ' --provider=openstack';
  }
  elsif ($launch_vcloud){
    $launch_command = ' --provider=vcloud';
  }
  return $launch_command;
}

# copies the configs over to ~/.bindle/ and notifies the user to fill in the required info
sub copy_over_config_templates {
  system("rsync -r config/* ~/.bindle/");
  system("echo 'export BINDLE_SETTINGS=~/.bindle' >> ~/.profile");
  system ("export BINDLE_SETTINGS=~/.bindle");
  $ENV{'BINDLE_SETTINGS'} = '/home/apatel/.bindle/';
  say "The config file doesn't exist! The file has now been included! Please fill in the config file for the corresponding environment you want to launch clusters on by executing 'vim ~/.bindle/<os/aws/vcloud>.cfg' and try again!";
  exit 1;  
}

# upgrade the configs to default templates if the keys don't match for the platform block
sub upgrade_outdated_configs {
  my ($abs_path,$rel_path) = @_;
  my $cfg_template = (split(/\//,$abs_path))[-1];
  my $template_configs = new Config::Simple("config/$cfg_template");
  my $tmplate_platform = $template_configs->param(-block=>'platform');
  my $default_configs = new Config::Simple($rel_path);
  my $cfg_platform = $default_configs->param(-block=>'platform');
  if (keys %$tmplate_platform == keys %$cfg_platform){
      return 0;
  }else{
      system("rsync -r config/* ~/.bindle/");
      say "The config file is outdated! Upgraded the config files. Please go to ~/.bindle/<os/aws/vcloud>.cfg, fill in the corresponding config file and then try again";
      exit 2;
  }
}

1;
