## About

This project is a wrapper around [Vagrant](http://www.vagrantup.com/) and
provides the ability to launch either a single node or a cluster of compute
nodes configured with one or more Bash shell scripts.  The big difference
between building a cluster with this script vs. Vagrant directly is Vagrant
provides a single pass at running provisioning script.  This tool, however,
launches one or more instances, runs a base Bash configuration script on each,
then queries Vagrant to identify the external and internal IP address of each
of the launched instances. This script then runs one or more "secondary"
provisioning scripts that can include variables substituted, for example, the
IP addreses and domain names of the other hosts in the cluster.  This
functionality makes it possible to build clusters of nodes that know about each
other without knowing the IP addreses ahead of time.

Together with this Vagrant-wrapping  script, we provide secondary provisioning
shell scripts that setup a single-node or multi-node SeqWare cluster configured
to use the Oozie workflow engine. Since this Vagrant wrapper is fairly generic
the same process can be adapted to build other cluster types to serve other
projects.  We include sample JSON configs below that show you how to build
nodes/clusters for the following projects:

* SeqWare Pipeline (with Oozie-Hadoop and/or Oozie-SGE backends) and associated SeqWare projects (WebService, MetaDB, etc)
* the ICGC DCC Data Portal web application and elasticsearch index (with both a small and large index option)
* the ICGC DCC Data Submission and Validation system (TBD)
* the ICGC DCC Extract, Transform, and Load system for creating elasticsearch indexes (TBD)

In the latest version of the script you can specify multiple nodes with their
own set of provisioning bash shell scripts making it easy to configure a single
node or cluster with a simple to author config file. In the near future the
mechanism of using shell scripts to configure nodes will be re-implemented (or
supplemented) with Puppet scripts which should make it easier to maintain
different clusters and node types.  We will also improve the seperation between
SeqWare and the generic functionality of this cluster builder.

## Installing 

Install VirtualBox from [Oracle](https://www.virtualbox.org/) which will let
you launch a local node or cluster of virtual machine nodes on your desktop or
local server. If you will *only* launch a node or cluster of nodes on Amazon
or an OpenStack cloud you can skip this step.

Install Vagrant using the package from their [site](http://www.vagrantup.com/).
You then need to install plugins to handle AWS and OpenStack. The Virtualbox
provider is available out of the box with Vagrant.

  vagrant plugin install vagrant-aws
  vagrant plugin install vagrant-openstack-plugin

## Getting "Boxes"

If you are running using VirtualBox you need to pre-download boxes which are
images of computers ready to use.  The easiest way to do this is to find the
URL of the base box you want to use here:

http://www.vagrantbox.es/

For example, to download the base Ubuntu 12.04 box you do the following:

  vagrant box add Ubuntu_12.04 http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box

For Amazon or an OpenStack cloud a "dummy" box will be used and is already
configured in the code.

## Configuration

Copy one of the files in templates/sample_configs/vagrant_launch.conf.template to the root dir of this
project (seqware-vagrant) and rename it vagrant_launch.conf.  Next, fill in
your various settings.  You can keep distinct settings for each of the backend
types which allows you to launch both AWS and OpenStack-based machines with
slightly tweaked differences.

## Running with the Wrapper

NOTE: this is out of date, see the "OICR Examples" section for current, cluster-launching examples.

We provide a wrapper script (vagrant_launch.pl) that helps to lauch an instance
in different cloud environments. It makes sure sensitive information is not
stored in files that will be checked in and also collects various files from
other parts of the SeqWare build.

    # for AWS
    perl vagrant_launch.pl --use-aws
    # for OpenStack
    perl vagrant_launch.pl --use-openstack
    # for VirtualBox
    perl vagrant_launch.pl --use-virtualbox

This script also lets you point to the config file explicitly, change the
working directory (which defaults to target, it's the location where Vagrant
puts all of its runtime files), point to different OS-specific setup script(s),
and skip the integration tests if desired:

    # example
    perl vagrant_launch.pl --use-aws --working-dir target-aws --config-files templates/server_setup_scripts/ubuntu_12.04_base_script.sh,templates/server_setup_scripts/ubuntu_12.04_database_script.sh,templates/server_setup_scripts/ubuntu_12.04_portal_script.sh --skip-it-tests

## OICR Examples

These are in flux right now but I'll try to keep the following up to date.  We're using this seqware-vagrant process for the following projects:

* ICGC DCC Portal
* SeqWare 

Keep in mind you will want to take a look at the Vagrant template (templates/Vagrantfile.template) and modify as needed for your backend (AWS, OpenStack, Virtualbox) since some params (like floating IP address) are not yet parameters.

### Setup

Make sure you setup your vagrant_launch.conf file as described in "Configuration".  See Brian for OICR-specific settings which are described in more detail here: https://wiki.oicr.on.ca/display/SEQWARE/Cluster+or+Node+Launching+with+Vagrant

### Single Node - All Projects

This is currently broken since I've refactored for cluster launching.  The plan is to generalize this vagrant_launch.pl script so you can choose single or cluster mode and you can choose how many worker nodes to launch.  In the mean time use the develop branch instead if you need to launch a single node otherwise use the sample commands below to launch 2 node clusters for testing.

### SeqWare - Cluster

This will launch a 2 node cluster with a worker and master node. It's designed to use Oozie-Hadoop (not Oozie-SGE but Alex did create config shell scripts for this too).

    perl vagrant_launch.pl --use-openstack --skip-it-tests --os-master-config-scripts templates/server_setup_scripts/ubuntu_12.04_master_script.sh --os-worker-config-scripts templates/server_setup_scripts/ubuntu_12.04_worker_script.sh --os-initial-config-scripts templates/server_setup_scripts/ubuntu_12.04_minimal_script.sh

The only issue with this right now is I don't think HBase is configured to work in HDFS/distributed mode.  Also, see the note above about hard-coded values in the Vagrantfile.template.

### ICGC DCC Portal - Cluster

This will spin up a standard, 2 node SeqWare cluster (using Oozie-Hadoop), will setup elasticsearch, will download a dump of the (small) elasticsearch DCC index, load the dump into elasticsearch, and launch the DCC Portal web app on port 8998.

Keep in mind you should look at the templates/Vagrantfile.template before you launch to make sure your floating IP addresses are correct.  Also, the specific index dump file and DCC Portal jar file are hard coded in the ubuntu_12.04_master_dcc_portal_script.sh script so you will want to change these if there's an update.  Also, take a look at templates/DCC/settings.yml which has the index name embedded and will need to change if the index is updated.

    perl vagrant_launch.pl --use-openstack --skip-it-tests --os-master-config-scripts templates/server_setup_scripts/ubuntu_12.04_master_script.sh,templates/server_setup_scripts/ubuntu_12.04_elasticsearch_node_script.sh,templates/server_setup_scripts/ubuntu_12.04_master_dcc_portal_script.sh --os-worker-config-scripts templates/server_setup_scripts/ubuntu_12.04_worker_script.sh,templates/server_setup_scripts/ubuntu_12.04_elasticsearch_node_script.sh --os-initial-config-scripts templates/server_setup_scripts/ubuntu_12.04_minimal_script.sh

Once this finishes launching you can browse the DCC Portal at http://<master_node_IP>:8998/.

Updated on 20130923:

    # setup your vagrant_cluster_launch.json config file, see templates/vagrant_cluster_launch.json.template
    perl vagrant_cluster_launch.pl --use-openstack --config-file vagrant_cluster_launch.json --skip-it-tests

The above is the next version which should be much nicer for dealing with flexible numbers of worker nodes. In testing.


## Debugging

If you need to debug a problem set the VAGRANT_LOG variable e.g.:

    VAGRANT_LOG=DEBUG perl vagrant_launch.pl --use-aws

Also you can use the "--skip-launch" option to just create the various launch
files not actually trigger a VM.

Vagrant will often report an error of the form ""Expected(200) <=> Actual(400 Bad Request)"." with no details.
See the following patch for a fix
https://github.com/jeremyharris/vagrant-aws/commit/1473c3a45570fdebed2f2b28585244e53345eb1d

## Shutting Down

You can terminate your instance via the provider interface (Open Stack, AWS, or VirtualBox).

## Manual Running Vagrant

You can use the Vagrantfile created by the launch script to manually start a
cluster node (note, you would have to run the vagrant_launch.pl at least once
before to get a target directory).  Change directory into the target dir.  This
command brings up a SeqWare VM on Amazon:

  cd target
  vagrant up --provider=aws

In case you need to re-run the provisioning script e.g. you're testing changes
and want to re-run without restarting the box:

  # just test shell setup
  vagrant provision --provision-with shell

## TODO

* need to setup HBase for the QueryEngine -- done
* need to edit the landing page to remove mention of Pegasus
* need to add code that will add all local drives to HDFS to maximize available storage (e.g. ephemerial drives) -- done
* ecryptfs -- done
* need to have a cluster provisioning template that works properly and coordinates network settings somehow
* should I add glusterfs in parallel since it's POSIX compliant and will play better with SeqWare or should I just use NFS?
* add teardown for cluster to this script
* need to add setup init.d script that will run on first boot for subsequent images of the provisioned node
* setup services with chkconfig to ensure a rebooted machine works properly -- done
* better integration with our Maven build process, perhaps automatically calling this to setup integration test environment -- done
* message of the day on login over ssh
* pass in the particular branch to use with SeqWare -- done
