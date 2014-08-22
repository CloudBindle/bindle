package cluster::provision;

use common::sense;
use IPC::System::Simple;
use autodie qw(:all);
use Getopt::Long;
use Config;
$Config{useithreads} or die('Recompile Perl with threads to run this program.');
use threads;
use Storable 'dclone';
use Carp::Always;

my ($configs, $cluster_configs, $work_dir);


sub provision_instances {
    my ($class, $cfgs, $cluster_cfgs,$target_dir, $launch_vcloud,$use_rsync) = @_;
    ($configs, $cluster_configs, $work_dir)=($cfgs, $cluster_cfgs,$target_dir);
    # first, find all the hosts and get their info
    my $hosts = find_cluster_info($cluster_configs,$work_dir);

    # now call ansible if configured
    return run_ansible_playbook($cluster_configs, $hosts);
}

sub find_cluster_info {
    my ($cluster_config,$work_dir) = @_;

    my (%cluster_info, @node_status, $vagrant_status);
    foreach my $node (sort keys %{$cluster_config}) {
        $vagrant_status = `cd $work_dir/$node && vagrant status`.'\n';
        chomp $vagrant_status;
        find_node_info(\%cluster_info, $vagrant_status);
    }

    return \%cluster_info;
}

sub find_node_info {
    my ($cluster_info, $vagrant_status) = @_;

    my $host_id = get_host_id_from_vagrant_status($vagrant_status);

    if ($host_id ne "" && defined($cluster_configs->{$host_id})) {
       $cluster_info->{$host_id} = host_information($work_dir, $host_id);
    }
 
}

sub get_host_id_from_vagrant_status {
    my ($status) = @_;

    if ($status =~ /Current machine states:\s+(\S+)\s+(active|running)/) { # openstack and vcloud ar running, aws is running
        return $1;
    } 
    die 'Was unable to get node infomation';
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

# this generates an ansible inventory and runs ansible
sub run_ansible_playbook {
  my ($cluster_configs, $hosts) = @_;

  # this could use a specific set module
  my %type_set = ();
  foreach my $host_name (sort keys %{$hosts}) {
    $type_set{$cluster_configs->{$host_name}{type}} = 1;
  }

  open (INVENTORY, '>', "$work_dir/inventory") or die "Could not open inventory file for writing";

  foreach my $type (keys %type_set){
    print INVENTORY "[$type]\n";
    foreach my $host_name (sort keys %{$hosts}) {
      my $cluster_config = $cluster_configs->{$host_name};
      my $host = $hosts->{$host_name};
      if ($type ne $cluster_config->{type}){
        next; 
      }
      print INVENTORY "$host_name\tansible_ssh_host=$host->{ip}\tansible_ssh_user=$host->{user}\tansible_ssh_private_key_file=$host->{key}\n";
    } 
  }
  print INVENTORY "[all_groups:children]\n";
  foreach my $type (keys %type_set) {
    print INVENTORY "$type\n";
  }
  close (INVENTORY); 


  if (not exists $configs->{ANSIBLE_PLAYBOOK}){
	  return 0;
  }
  # run playbook command
  # I'm sure this "cluster" parameter is not how one should do it in Perl, but this seems to work with the call from the launcher which inserts the package
  # as the first parameter
  return run_ansible_command("cluster", $work_dir, $configs);
}

sub run_ansible_command{
  my ($package, $work_dir, $configs) = @_;
  my $time = `date +%s.%N`;
  chomp $time;
  # create JSON file to pass all defined variables
  # note that ansible variables are lower case by convention while for backwards compatibility, our variables are upper case
  # thus lc while exporting
  open ANSIBLE_VARIABLES, ">$work_dir/variables.$time.json" or die $!;
  my %hash = %{$configs};
  my %lchash = map { lc $_ => $hash{$_} } keys %hash;
  my $json = JSON->new->allow_nonref;
  print ANSIBLE_VARIABLES $json->encode( \%lchash );
  close ANSIBLE_VARIABLES;

  # preserve colour for easy readability in head and tail
  # also save a copy without buffering (unlike tee) by using script -c
  open WRAPSCRIPT, ">$work_dir/wrapscript.$time.sh" or die $!;
  print WRAPSCRIPT "#!/usr/bin/env bash\n";
  print WRAPSCRIPT "set -o errexit\n";
  print WRAPSCRIPT "export ANSIBLE_FORCE_COLOR=true\n";
  print WRAPSCRIPT "export ANSIBLE_HOST_KEY_CHECKING=False\n";
  print WRAPSCRIPT "ansible-playbook -v -i $work_dir/inventory $configs->{ANSIBLE_PLAYBOOK} --extra-vars \"\@$work_dir/variables.$time.json\" \n";
  close (WRAPSCRIPT);
  print "Ansible command: script -c $work_dir/wrapscript.$time.sh $work_dir/ansible_run.$time.log\n";
  system("chmod a+x $work_dir/wrapscript.$time.sh");
  return system("script -c $work_dir/wrapscript.$time.sh $work_dir/ansible_run.$time.log");
}

sub run {
    my ($cmd, $hostname, $retries) = @_;

    if (!defined($retries) || $retries < 0) {
      $retries = 0;
    }

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
        while($retries >= 0) { 
          if (!system($final_cmd)) { last; }
          $retries--;
          sleep 10;
        }
        say 'launched machine!';
    }
    else {
        while($retries >=0) {
          
        if (!system($final_cmd)) { last; }
          $retries--;
          sleep 10;
        }
    }
}

1;
