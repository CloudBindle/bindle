## About

Please use [HubFlow](http://datasift.github.io/gitflow/) for development. The
working branch is "develop".

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

Install Vagrant using the package from their [site](http://downloads.vagrantup.com/).
For example:

  wget http://files.vagrantup.com/packages/a40522f5fabccb9ddabad03d836e120ff5d14093/vagrant_1.3.5_x86_64.deb
  sudo dpkg --install vagrant_1.3.5_x86_64.deb

Make sure you choose the right package format for your OS, the above is for Ubuntu.

You then need to install plugins to handle AWS and OpenStack. The Virtualbox
provider is available out of the box with Vagrant.

  vagrant plugin install vagrant-aws
  vagrant plugin install vagrant-openstack-plugin

The vagrant_cluster_launch.pl Perl script requires Perl (of course) and also a
few modules.  You can install these using [CPAN](http://www.cpan.org/) or via
your distribution's package management system:

* Getopt::Long: should be installed by default with Perl
* Data::Dumper: should be installed by default with Perl
* JSON: eg "sudo apt-get install libjson-perl"
* Template: eg "sudo apt-get install libtemplate-perl"

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

Since this Vagrant wrapper can be used for many different projects based on the
Bash shell scripts used to configure the hosts, we included several example
configuration templates in:

    templates/sample_configs/

Copy one of the files (for example
templates/sample_configs/vagrant_cluster_launch.seqware.single.json.template)
to the root dir of this project (seqware-vagrant) and rename it
to vagrant_cluster_launch.json:

    cp templates/sample_configs/vagrant_cluster_launch.seqware.single.json.template vagrant_cluster_launch.json

By using this destination filename and location the .gitignore file will
prevent you from accidently checking in this file (it will contain sensitive
information like your Amazon key).

Next, fill in your various settings depending on what cloud provider you use
(VirtualBox, Amazon, or OpenStack).  You can keep distinct settings for each of
the backend types which allows you to launch both AWS and OpenStack-based
machines with the same config file.

At this point you will also want to examine the sections describing each of the
nodes. Please use "master" as the name of the master node (we have assumptions
in our code/config templates). Feel free to add or remove worker nodes (min 0,
max recommended 10) and alter the list of "secondary" Bash shell config scripts
that are run after the node is launched.

If you use the template recommended above you will have a 1 node Hadoop cluster
(with Mapred, HDFS, HBase, Oozie, Hue, etc installed) along with the SeqWare
software stack installed.  This environment should be ready for use with out
Getting Started Guides for this project. You can also choose another template,
such as "templates/sample_configs/vagrant_cluster_launch.seqware.cluster.json.template",
that will give you a 4 node cluster.

## Running with the Wrapper

The wrapper script that controls the system described above is called "vagrant_cluster_launch.pl".
Examples of launching in different environments (assuming you have a
"vagrant_cluster_launch.json" file in the current directory) include:

    # for AWS
    perl vagrant_cluster_launch.pl --use-aws
    # for OpenStack
    perl vagrant_cluster_launch.pl --use-openstack
    # for VirtualBox
    perl vagrant_cluster_launch.pl --use-virtualbox

This script also lets you point to the config file explicitly, change the
working Vagrant directory (which defaults to target, it's the location where
Vagrant puts all of its runtime files), and skip the integration tests (for
SeqWare) if desired (the full integration tests take 1 hour!):

    # example, see source for all args
    perl vagrant_cluster_launch.pl --use-aws --working-dir target-aws --config-file vagrant_cluster_launch.json --skip-it-tests

## SeqWare Examples

These sections show specific examples taken from our templates. These cover
single-node SeqWare, SeqWare clusters, and other OICR projects as well.  The
config JSON templates and provisioning Bash shell scripts should provide ample
examples of how to use vagrant_cluster_launch.pl with other tools. Using these
examples, you will need to modify the configuration template and copy them to
vagrant_cluster_launch.json (or another file, using the --config-file option).

### SeqWare - Single Node

This will launch a single node that's a self-contained SeqWare box. This is
suitable for snapshoting for redistribution as a machine image (e.g. AMI on
Amazon's cloud, VirtualBox snapshot, etc).

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.seqware.single.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for you 
    perl vagrant_cluster_launch.pl --use-openstack

### SeqWare - Cluster

This will launch a 4 node cluster with 3 workers and one master node. You can
reduce or increase the number of worker nodes depending on your requirements.
Keep in mind the nodes are provisioned sequentially so adding nodes will increase
the runtime.

#### Oozie Hadoop

This is the default engine that the vast majority of people will want to use:

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.seqware.cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for you 
    perl vagrant_cluster_launch.pl --use-openstack

#### Oozie SGE

This is really just for SeqWare's own internal testing. We support a workflow engine that talks to SGE via an Oozie plugin and this configuration will let you spin up an SGE cluster configured to work with SeqWare:

TODO: the SGE scripts need to be generalized for a cluster

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.seqware.sge_cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for you 
    perl vagrant_cluster_launch.pl --use-openstack

##### Oozie SGE with dedicated web service and database servers

For increased performance, it is possible to allocate dedicated database and web service servers


    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.seqware.cluster.dedicatedServers.json.template
    # launch, use the correct command line args for you 
    perl vagrant_cluster_launch.pl --use-openstack



## OICR Examples

SeqWare isn't the only project using this Vagrant wrapper.  We're using the
same infrastructure for running the ICGC DCC data portal on OpenStack and
Amazon. In the future we will add additional ICGC DCC software project
profiles. These are not ready for outside users at this time but we expect
other users in the future to launch DCC Portals and Validation systems using
something similar to the below.

### General OICR Settings

The templates below do
not include our OpenStack settings but you can see Brian for OICR-specific
settings which are also described in more detail here:
https://wiki.oicr.on.ca/display/SEQWARE/Cluster+or+Node+Launching+with+Vagrant

### ICGC DCC Portal - Small Cluster

This will spin up a standard, 2 node SeqWare cluster (using Oozie-Hadoop), will
setup elasticsearch, will download a dump of the (small) elasticsearch DCC
index, load the dump into elasticsearch, and launch the DCC Portal web app on
port 8998.

Keep in mind you should edit the json below before you launch to make sure your
floating IP addresses and other settings are correct.  Also, the specific index
dump file and DCC Portal jar file are hard coded in the provision scripts
referenced inside the JSON so you will want to change these if there's an
update.  Also, take a look at templates/DCC/settings.yml which has the index
name embedded and will need to change if the index is updated.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.dcc_small_portal.cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for you
    perl vagrant_cluster_launch.pl --use-openstack

Once this finishes launching you can browse the DCC Portal at http://<master_node_IP>:8998/.

### ICGC DCC Portal - Large Cluster

This is the same as the previous example but defaults to an 8 node cluster (one
master, 7 workers). It also calls scripts that reference the large
Elasticsearch DCC Portal index dumps. In the future we will increase this
number, optimize the configuration to better take advantage of the node number,
and explore HA options.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.dcc_large_portal.cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for you
    perl vagrant_cluster_launch.pl --use-openstack

## Debugging

If you need to debug a problem set the VAGRANT_LOG variable e.g.:

    VAGRANT_LOG=DEBUG perl vagrant_cluster_launch.pl --use-aws

Also you can use the "--skip-launch" option to just create the various launch
files not actually trigger a VM.

Vagrant will often report an error (when using AWS of OpenStack) of the form
""Expected(200) <=> Actual(400 Bad Request)"." with no details.  See the
following patch for a fix to get more information:

https://github.com/jeremyharris/vagrant-aws/commit/1473c3a45570fdebed2f2b28585244e53345eb1d

## Shutting Down

You can terminate your instance via the provider interface (Open Stack, AWS, or VirtualBox).

You can also use Vagrant to terminate your instances, simply cd into the target directory (or whatever directory you specified with --working-dir) and issue:

    vagrant status

This will show you what's currently running.  You can then terminate them using:

    vagrant destroy

That will terminate all your instances associated with this particular working directory.  Please double-check the provider-specific console to ensure your instances shut down properly.

*Do not forget to shut down your instances!*

## Manual Running Vagrant (Out of Date)

The following directions will not work reliably since the
vagrant_cluster_launch.pl script actually performs multiple passes of
configuration. I'm leaving them here for historic reasons since it's still
useful to see how Vagrant works.

You can use the Vagrantfile created by the launch script to manually start a
cluster node (note, you would have to run the vagrant_cluster_launch.pl at
least once before to get a target directory).  Change directory into the target
dir.  This command brings up a SeqWare VM on Amazon:

  cd target
  vagrant up --provider=aws

In case you need to re-run the provisioning script e.g. you're testing changes
and want to re-run without restarting the box:

  # just test shell setup
  vagrant provision --provision-with shell

## TODO

The list of TODO items, some of which are out-of-date.  See the
vagrant_cluster_launch.pl script for more TODO items too.

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
* would be great to have threading in here so nodes launch in parallel

