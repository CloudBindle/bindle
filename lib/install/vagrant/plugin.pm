package install::vagrant::plugin;

  use strict;
  use warnings;

  use Data::Dumper;

  use Net::OpenSSH;

  sub openstack {
    my ($class, $ssh) = @_;
    
    print "Installing Vagrant OpenStack plugin\n";    

    $ssh->capture('sudo vagrant plugin install vagrant-openstack-plugin');
    $ssh->error and die "Couldn't install Vagrant OpenStack Plugin";

    fix_open_stack_plugin($ssh);
  }

  sub aws {
    my ($class, $ssh) = @_;
    
    print "Installing Vagrant amazon web service plugin\n";    

    $ssh->capture('sudo vagrant plugin install vagrant-aws');
    $ssh->error and die "Couldn't install Vagrant OpenStack Plugin";

  }

  sub fix_open_stack_plugin {
    my ($ssh) = @_;

    print "fixing Vagrant OpenStack plugin\n";
   
    $ssh->capture('sudo wget --quiet -O ~/.vagrant.d/gems/gems/vagrant-openstack-plugin-0.3.0/lib/vagrant-openstack-plugin/action/sync_folders.rb https://raw.github.com/cloudbau/vagrant-openstack-plugin/48eac2932fa16ccd5fab2e1d2e0d04047f3be7bd/lib/vagrant-openstack-plugin/action/sync_folders.rb');
    $ssh->error and die "Couldn't fix Vagrant Openstack Plugin: ".$ssh->error;
  }

1;
