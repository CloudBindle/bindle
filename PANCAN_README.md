# TCGA/ICGC PanCancer - Computational Node/Cluster Launch SOP

This is our SOP for how to launch clusters/nodes using SeqWare-Vagrant
specifically for use by the TCGA/ICGC PanCancer project.  In addition to
providing production cluster environments for analyzing samples on the clouds
used by the PanCancer project, the SeqWare-Vagrant process can also be used to
create workflow development environments.

## Use Cases

There are really two use cases for this technology by the PanCancer project.
First, to create a production environment for running analytical workflows for
PanCancer.  Second, to create a workflow development environment for creating
new workflows for the project.

### Build a PanCancer Workflow Running Environment

SeqWare-Vagrant for PanCancer is intended to be used to create clusters of
virtual machines running in one of several cloud environments used by the
PanCancer project.  These clusters are used to process approximately 2,500
whole human genomes using standardized workflows: BWA and variant calling. This
constitutes "Phase II" of the project. "Phase III" will see the use of this
technology stack by a variety of researchers across the cloud environments
employed by the project to answer their specific research questions.

The environments built with SeqWare-Vagrant provide both GridEngine and Hadoop
execution environments along with the full collection of SeqWare tools.

This process can be used to create both single compute instances for
small-scale computation and clusters of compute instances suitable for
larger-scale computation.

#### Steps

* decide on cloud environment and request an account, when you sign up you should get the SeqWare-Vagrant settings you need
* download and install (our use our pre-created "launcher" VM images if available on this cloud):
** SeqWare-Vagrant
    * Vagrant
    * Vagrant plugins and/or VirtualBox
* copy and customize the SeqWare-Vagrant template of your choice with your appropriate cloud settings
* launch your cluster or node using vagrant_cluster_launch.pl
* ssh into your cluster
* launch SeqWare workflow(s) and monitor their results, this can be automated with a decider and is the process we use to automate "Phase II" of the project
* _or_
* use the environment for developing, building, or using your own tools (e.g. "Phase III" activities), the following environments are available for your use:
    * GridEngine
    * SeqWare
    * Hadoop

#### Detailed Example - Amazon Web Services Single Node/Cluster of Nodes with the HelloWorld Workflow

Here I will show you how to create a single compute node running on AWS and
capable or executing the HelloWorld workflow to ensure your environment is
working.  Another tutotrial will show you how to install the PanCancer BWA-Mem
Workflow 2.1. I chose AWS for its ease of access however please keep in mind
the AWS cloud is not a PanCancer participating cloud. This information is
provided for illustration purposes only. You can use AWS to work with
synthetic/non-controlled access data but please use a PanCancer approved cloud
for computation on controlled access data.  The mechanism for other clouds is
identical to the example below, however, so the example shown below should be
extremely helpful in accessing PanCancer clouds.

##### Step - Get an Account

First, sign up for an account on the AWS website, see http://aws.amazon.com for
directions.

##### Step - Create a Launcher Host

Next, you can create a "launcher" host. This is your gateway to the system and
allows you to launch individual computational nodes or clusters of nodes that
actually do the processing of data.  It also is the location to run the
"decider" that will schedule the BWA workflow running on your many clusters in
this cloud.  This latter topic will be discussed in another guide focused on
workflow launching and automation.

The launcher host also improves the isolation of your computational
infrastructure.  It should be the only host accessible via SSH, should use SSH
keys rather than passwords, use a non-standard SSH port, and, ideally, include
Failtoban or another intrusion deterant.  For AWS, please see the extensive
documentation on using security groups to isolate instances behind firewalls
and setup firewall rules at http://aws.amazon.com.

For our purposes we use an Ubuntu 12.04 AMI provided by Amazon.  See the
documentation on http://aws.amazon.com for information about programmatic,
command line, and web GUI tools for starting this launcher host.  For the
purposes of this tutorial we assume you have successfully started the launcher
host using the web GUI at http://aws.amazon.com.  The screen shot below shows
the selection of the AMI from the list provided by Amazon.

    SCREENSHOT

Next, we recommend you use an "t1.micro" instance type as this is inexpensive
($14/month) to keep running constantly. 

We also assume that you have setup your firewall (security group) and have
produced a .pem SSH key file for use to login to this host.  In my case my key
file is called "brian-oicr-3.pem" and, once launched, I can login to my
launcher host over SSH using something similar to the following:

    ssh -i brian-oicr-3.pem ubuntu@ec2-54-221-150-76.compute-1.amazonaws.com

Up to this point the activities we have described are not at all specific to
the PanCancer project.  If you have any issues following these steps please see
the extensive tutorials online for launching a EC2 host on AWS.  Also, please
be aware that Amazon charges by the hour, rounded up.  You are responsible for
any Amazon expenses you incure with your account.

#### Step - Install SeqWare-Vagrant, Vagrant, and Other Tools on the Launcher

The next step is to configure Vagrant (cloud-agnostic VM launcher),
SeqWare-Vagrant (our tool for wrapping Vagrant and setting up a computational
environment/cluster), and various other dependencies to get these to work.  Log
onto your launcher now and perform the following actions as ubuntu (who also
has sudo).

Much more information about SeqWare-Vagrant can be found at our GitHub site
https://github.com/SeqWare/vagrant. In particular take a look at the README.md.

Note the "$" is the Bash shell prompt in these examples and "#" is a comment:

    # download SeqWare Vagrant 1.1
    $ wget http://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/seqware-vagrant_1.1.tar.gz
    $ tar zxf seqware-vagrant_1.1.tar.gz
    $ cd seqware-vagrant_1.1
    
    # install seqware-vagrant dependencies, again see README for SeqWare-Vagrant
    $ sudo apt-get install libjson-perl libtemplate-perl
    
    # make sure you have all the dependencies needed for SeqWare-Vagrant, this should not produce an error
    $ perl -c vagrant_cluster_launch.pl
    
    # now install the Vagrant tool which is used by SeqWare-Vagrant
    $ wget https://dl.bintray.com/mitchellh/vagrant/vagrant_1.4.3_x86_64.deb
    $ sudo dpkg -i vagrant_1.4.3_x86_64.deb
    $ vagrant plugin install vagrant-aws

At this point you should have a launcher with SeqWare-Vagrant and associated
tools installed. This is now the machine from which you can create one or more
SeqWare nodes/clusters for use with various workflows, GridEngine, or Hadoop.

In the future we will provide pre-configured launcher VMs on the various clouds
to eliminate the installation tasks above.

#### Step - Configuration

Now that you have SeqWare-Vagrant and dependencies installed the next step is
to launch computational nodes or clusters that will run workflows via SeqWare,
launch cluster jobs via GridEngine, or perform MapReduce jobs.  In this step we
will launch a standalone node and in the next command block I will show you how to
launch a whole cluster of nodes that are suitable for larger-scale analysis. 

Assuming you are still logged into you launcher node above you will do the
following to setup a computational node.  The steps below assume you are
working in the seqware-vagrant_1.1 directory:

    # copy the template used to setup a SeqWare single compute node for PanCancer
    $ cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_node.json.template vagrant_cluster_launch.json 
    # modify the .json template to include your settings, for AWS you need to make sure you fill in the "AWS_*" settings
    $ vim vagrant_cluster_launch.json

Alternatively, you may want to launch a compute cluster instead of a single
node.  In that case, use a different template.  You can customize the number of
worker nodes by increasing the number in the worker array, see the config json
file.  We typically use between 3 and 6 worker nodes which, depending on the
cloud, would align a 60x coverage genome in between 10 and 5 hours respectiely.

    # copy the template used to setup a SeqWare compute cluster for PanCancer
    $ cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_cluster.json.template vagrant_cluster_launch.json 
    # modify the .json template to include your settings, for AWS you need to make sure you fill in the "AWS_*" settings, also customize number of workers
    $ vim vagrant_cluster_launch.json

#### Step - Launch a SeqWare Node/Cluster

Now that you have customized the settings in vagrant_cluster_launch.json the
next step is to launch a computational node. Note, each launch of a
node/cluster gets its own "--working-dir", you cannot resuse these.  Within the
working dir you will find a log for each node (simply master.log for a
single-node launch) and a directory for each node that is used by the vagrant
command line tool (the "master" directory for a single-node launch). The latter
is important for controlling your node/cluster once launched. 

    # now launch the compute node
    $ perl vagrant_cluster_launch.pl --use-aws --working-dir target-aws-1 --config-file vagrant_cluster_launch.json

You can follow the progress of this cluster launch in another terminal with.
Use multiple terminals to watch logs for multiple-node clusters if you desire:

    # watch the log
    $ tail -f target-aws-1/master.log 

Once this process complete you should see no error messages from
"vagrant_cluster_launch.pl". If so, you are ready to use your cluster/node.

#### Step - Log In To Node/Cluster

Vagrant provides a simple way to log into a launched node/cluster.  Typically you will only want/need to login to the master node.  For example:

    # log into the master node
    $ cd target-aws-1/master
    $ vagrant ssh

This will log you into the master node.  You can change user to the seqware
user which will be used for subsequent steps or root if you need to do some
administration of the box.

    # switch user to seqware
    $ sudo su - seqware
    # or switch user to root (not generally needed!)
    $ sudo su -

#### Step - Verify Node/Cluster with HelloWorld

Now that you have a node or a cluster the next step is to launch a sample
HelloWorld SeqWare workflow to ensure all the infrastructure on the box is
functioning correctly.  Depending on the template you used this may or may not
be already installed under the seqware user account. If not, you can download a
copy of the workflow and install it yourself. That is what these commands
assume.

    # assumes you have logged into your master node and switched to the seqware user

#### Step - Terminate Node/Cluster

At this point 

#### Next Steps

Much more information can be found in the README for the SeqWare-Vagrant project, see https://github.com/SeqWare/vagrant

In latter sections of this document you can see more information about:

* differences with other PanCancer clouds environments, what needs to change in the above detailed steps
* running other workflows, like BWA-Mem
* different templates available, for example, ones that automatically install the BWA-Mem workflow


### Build a Workflow Development Environment

SeqWare-Vagrant can be used to create a workflow development environment that
can be used to create SeqWare workflows or other tools. These can be used in
Phase II activities (for SeqWare workflows) or Phase III (SeqWare workflows or
other tools).  Like the production workflow running environment, the
development environment provides both GridEngine and Hadoop along with the
various SeqWare components.

The reason PanCancer is using SeqWare workflows specifically for Phase II is it
provides a mechanism to define an analytical workflow that combines a variety
of tools.  It is tool agnostic, you can make workflows with whatever components
you like.  These workflows are then "packaged" into a zip file format that the
SeqWare system recognizes and knows how to run.  In this way SeqWare workflows
are portable between SeqWare environments, allowing us to move updated or new
workflows between the various PanCancer cloud environments.  Groups that create
SeqWare workflows can exchange the workflows and can be assured they will run
across all the various SeqWare-Vagrant-created environments. SeqWare workflows
also integrate with metadata tracking tools and deciders, allowing for
automated triggering.  This allows us to detect new samples in Phase II, launch
clusters using SeqWare-Vagrant, and then automatically run workflows on those
environments.

You can find more information on how to build SeqWare workflows and use the
SeqWare tools at our project website http://seqware.io.

#### Steps

* you will be working locally using VirtualBox, make sure you have a Linux or Mac available to work on with 16G of RAM
* download and install:
** SeqWare-Vagrant
** Vagrant
** VirtualBox
* copy and customize the SeqWare-Vagrant template of your choice (a single node only, do not use a cluster profile)
* launch your cluster or node using vagrant_cluster_launch.pl, select "--use-virtualbox" 
* ssh into your node
* Vagrant will automatically create a vagrant directory ("/vagrant" on the VM and within your "working_dir/master" dir) that is shared between your host and the VM 
* create new SeqWare workflows in this "working_dir/master" dir, please see the Developer Getting Started Guide at http://seqware.io
* you can compile SeqWare workflows on your local computer or on the VM
* launch SeqWare workflow(s) on your VM to test them and monitor their results
* package your workflow as a zip bundle (see Developer guide) once your testing is complete, this can be distributed to other clouds for installation and execution

#### Detailed Steps Using VirtualBox Locally

TODO

## Configuration Profiles

First, please see the general documentation on SeqWare-Vagrant, the tool we use
to build these clusters using Vagrant. This will walk you through the process
of using this software.  This tool allows us to create clusters in different
cloud environments using a common set of configuration scripts.  We have used
this project to prepare two different profiles, one for building clusters of
VMs and another for single, stand-alone VMs.  In addition, each of those can
optionally install our reference BWA (and potentially other) workflows.  This
latter process can be very time consuming so that is why we provide a profile
with and without the workflow(s) pre-installed.

### Cluster Without Workflows

In this environment we create a cluster of VMs but it does not have any
PanCancer workflows pre-installed.  This saves provisioning runtime, which can
be as short as 20 minutes, and gives you flexibility to install
newer/alternative/custom workflows.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment
    perl vagrant_cluster_launch.pl --use-openstack

### Cluster With BWA Workflow

In this environment we create a cluster of VMs with the PanCancer BWA Workflow 2.0 installed.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.bwa_workflow_2_0.seqware.install.sge_cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment
    perl vagrant_cluster_launch.pl --use-openstack

### Single Instance without Workflows

In this environment we create a single VM but it does not have any PanCancer
workflows pre-installed.  This saves provisioning runtime which can be as short
as 20 minutes and gives you flexibility to install newer/alternative workflows.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_node.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment
    perl vagrant_cluster_launch.pl --use-openstack

### Single Instance with Workflows

In this environment we create a VM with the PanCancer BWA Workflow 2.0 installed.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.bwa_workflow_2_0.seqware.install.sge_node.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment
    perl vagrant_cluster_launch.pl --use-openstack

## Notes for the EBI Embassy Cloud (vCloud)

The Embassy Cloud at EBI uses vCloud.  The Vagrant vCloud plugin has limited
functionality and, therefore, only single nodes can be launched there.

## Notes for BioNimbus (OpenStack)

BioNimbus uses OpenStack and the Vagrant OpenStack plugin is quite stable. You
can launch VM clusters or single nodes.

## Notes for OICR (OpenStack)

OICR uses OpenStack internally for testing and the Vagrant OpenStack plugin is
quite stable.  The cluster is not available to the general PanCancer group.

# change your settings
# this is where you need to populate the various OpenStack keys
ubuntu@brian-launcher:~/seqware-vagrant$ cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_node.json.template vagrant_cluster_launch.json

# now launch a host
ubuntu@brian-launcher:~/seqware-vagrant$ perl vagrant_cluster_launch.pl --use-openstack --working-dir target-os-1 --config-file vagrant_cluster_launch.json


###OpenStack
    $ vagrant plugin install vagrant-openstack-plugin

At this point you should have a launcher with SeqWare-Vagrant and associated
tools installed.

# change your settings
# this is where you need to populate the various OpenStack keys
ubuntu@brian-launcher:~/seqware-vagrant$ cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_node.json.template vagrant_cluster_launch.json

# now launch a host
ubuntu@brian-launcher:~/seqware-vagrant$ perl vagrant_cluster_launch.pl --use-openstack --working-dir target-os-1 --config-file vagrant_cluster_launch.json

### Notes for Annai Systems (BioComputeFarm)

## Notes for Amazon (AWS)

OICR uses AWS internally for testing and the AWS Vagrant plugin is quite
stable. The cluster is available for any PanCancer user but is not officially
part of the Phase II activities.

