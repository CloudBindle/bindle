package cluster::config;

use Config::Simple;
use common::sense;
use Carp::Always;
use autodie qw(:all);
use Config;
use Storable 'dclone';
use Data::Dumper;
use File::Spec;
use Cwd 'abs_path';

sub read_config {
    my ($class, $platform, $cluster_name) = @_;

    my $config = new Config::Simple();

    my $config_file = $ENV{"HOME"}."/.bindle/$platform.cfg";

    copy_over_config_templates() unless (-e $config_file );
  
    $config->read($config_file) or die $config->error();

    return $config;
}

#extracts all the platform related information from the config file
sub extract_general_config {
    my ($general_config, $config, $platform) = @_;

    my $selected_platform = uc $config->param('platform.type');
  
    foreach my $key (sort keys $config->param(-block=>'platform')) {
      # define the "boxes" used for each provider
    # These may be changed in the config file
    # you can override for VirtualBox only via the json config
    # you can find boxes listed at http://www.vagrantbox.es/
    if($key =~ /box|gluster/){
      $general_config->{uc $key} = $config->param('platform.'.$key);
    }
    else{
      $general_config->{$selected_platform.'_'.(uc $key)} = $config->param('platform.'.$key);
    }
  }
  
  my $pem_file = $config->param('platform.ssh_key_name');
  $general_config->{'VCLOUD_USER_NAME'} = $config->param('platform.ssh_username')
            if ($platform eq 'vcloud');          
  $general_config->{$selected_platform.'_SSH_PEM_FILE'} = "~/.ssh/".$pem_file.".pem";
  $general_config->{'SSH_PRIVATE_KEY_PATH'} = "~/.ssh/".$pem_file.".pem";

  return $general_config;
  
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

# copies the configs over to ~/.bindle/ and notifies the user to fill in the required info
sub copy_over_config_templates {
  system("rsync -r config/* ~/.bindle/");
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
      if (-e "$abs_path.old"){
          my $i = 1;
          my $stop = 0;
          while (not $stop){
              if (-e "$abs_path.old.$i"){
                  $i += 1;
              }
              else{
                  $stop = 1;
                  say "The config file is outdated! Created backup of your config file and is located at $abs_path.old.$i";
                  system("cp $abs_path $abs_path.old.$i");
              }
          }
      }
      else{
           system("cp $abs_path $abs_path.old");
           say "The config file is outdated! Created backup of your config file and is located at $abs_path.old";
      }
      system("cp config/$cfg_template ~/.bindle/$cfg_template");
      say "Upgraded $cfg_template to the newer version! Please go to ~/.bindle/<os/aws/vcloud>.cfg, fill in the corresponding config file and then try again";
      exit 2;
  }
}

1;
