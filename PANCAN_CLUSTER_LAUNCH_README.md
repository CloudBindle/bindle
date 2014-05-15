# TCGA/ICGC PanCancer - Computational Node/Cluster Launch SOP

This is our SOP for how to launch clusters/nodes using Bindle
specifically for use by the TCGA/ICGC PanCancer project.  In addition to
providing production cluster environments for analyzing samples on the clouds
used by the PanCancer project, the Bindle process can also be used to
create workflow development environments.

## Use Cases

There are really two use cases for this technology by the PanCancer project.
First, to create a production environment for running analytical workflows for
PanCancer.  Second, to create a workflow development environment for creating
new workflows for the project. For this guide we will focus on the first.

### Build a PanCancer Workflow Running Environment

Bindle for PanCancer is intended to be used to create clusters of
virtual machines running in one of several cloud environments used by the
PanCancer project.  These clusters are used to process approximately 2,500
whole human genomes using standardized workflows: BWA and variant calling. This
constitutes "Phase II" of the project. "Phase III" will see the use of this
technology stack by a variety of researchers across the cloud environments
employed by the project to answer their specific research questions.

The environments built with Bindle provide both GridEngine and Hadoop
execution environments along with the full collection of SeqWare tools.

This process can be used to create both single compute instances for
small-scale computation and clusters of compute instances suitable for
larger-scale computation.

#### Steps

* decide on cloud environment and request an account, when you sign up you should get the Bindle settings you need
* download and install (our use our pre-created "launcher" VM images if available on this cloud):
    * Bindle
    * Vagrant
    * Vagrant plugins and/or VirtualBox
* copy and customize the Bindle template of your choice with your appropriate cloud settings
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

#### Step - Install Bindle, Vagrant, and Other Tools on the Launcher

The next step is to configure Vagrant (cloud-agnostic VM launcher),
Bindle (our tool for wrapping Vagrant and setting up a computational
environment/cluster), and various other dependencies to get these to work.  Log
onto your launcher now and perform the following actions as ubuntu (who also
has sudo).

Much more information about Bindle can be found at our GitHub site
https://github.com/SeqWare/vagrant. In particular take a look at the README.md.

Note the "$" is the Bash shell prompt in these examples and "#" is a comment:

    # download SeqWare Vagrant 1.2
    $ wget http://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/bindle_1.2.tar.gz
    $ tar zxf bindle_1.2.tar.gz
    $ cd bindle_1.2
    
    # install bindle dependencies, again see README for Bindle
    $ sudo apt-get update
    $ sudo apt-get install libjson-perl libtemplate-perl make gcc
    
    # make sure you have all the dependencies needed for Bindle, this should not produce an error
    $ perl -c vagrant_cluster_launch.pl
    
    # now install the Vagrant tool which is used by Bindle
    $ wget https://dl.bintray.com/mitchellh/vagrant/vagrant_1.4.3_x86_64.deb
    $ sudo dpkg -i vagrant_1.4.3_x86_64.deb
    $ vagrant plugin install vagrant-aws

At this point you should have a launcher with Bindle and associated
tools installed. This is now the machine from which you can create one or more
SeqWare nodes/clusters for use with various workflows, GridEngine, or Hadoop.

In the future we will provide pre-configured launcher VMs on the various clouds
to eliminate the installation tasks above.

#### Step - Configuration

Now that you have Bindle and dependencies installed the next step is
to launch computational nodes or clusters that will run workflows via SeqWare,
launch cluster jobs via GridEngine, or perform MapReduce jobs.  In this step we
will launch a standalone node and in the next command block I will show you how to
launch a whole cluster of nodes that are suitable for larger-scale analysis. 

Assuming you are still logged into you launcher node above you will do the
following to setup a computational node.  The steps below assume you are
working in the bindle_1.2 directory:

    # copy the template used to setup a SeqWare single compute node for PanCancer
    $ cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_node.json.template vagrant_cluster_launch.json 
    # modify the .json template to include your settings, for AWS you need to make sure you fill in the "AWS_*" settings
    $ vim vagrant_cluster_launch.json
    # paste your key pem file, whatever you call it
    $ vim ~/.ssh/brian-oicr-3.pem
    $ chmod 600 /home/ubuntu/.ssh/brian-oicr-3.pem

Make sure you have copied your key to this machine (your pem file). I suggest
you use IAM to create limited scope credentials.  See the Amazon site for more
info.

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
copy of the workflow and install it yourself following our guides on
http://seqware.io (see
https://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13.zip).
The commands below assume the workflow is installed into
provisioned-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13.

    # assumes you have logged into your master node and switched to the seqware user
    $ ls provisioned-bundles/
    Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13
    # now run the workflow
    $ seqware bundle launch --dir provisioned-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13 

This command should finish without errors.  If there are problems please report
the errors to the SeqWare user group, see http://seqware.io/community/ for
information about posting to our mailing list.

#### Step - Terminate Node/Cluster

At this point you have successfully ran a workflow.  You can use this node or
cluster to run real workflows or just as a general GridEngine or Hadoop
environment.  Those topics are beyond the scope of this document but are
covered in other SOPs.  When you finish with a node or cluster you can
terminate it or, dependening on the environment, you can suspend it for use
later.  Keep in mind suspend works for single nodes but clusters of nodes
cannot be suspended and then booted up later again on most cloud infrastructure
because IP addresses typically change and this disrupts things like GridEngine
and Hadoop.

    # terminate the cluster/node
    $ cd target-aws-1/master
    $ vagrant destroy

You should always check in the AWS console (or OpenStack, vCloud, or other
console for a different cloud) that your nodes have been terminated otherwise
you will be billed for a machine you think is terminated.

#### Next Steps

Much more information can be found in the README for the Bindle project, see https://github.com/SeqWare/vagrant

In latter sections of this document you can see more information about:

* differences with other PanCancer clouds environments, what needs to change in the above detailed steps, see "Cloud-Specific Notes" below
* different templates available, for example, ones that automatically install the BWA-Mem workflow, see "Additional Configuration Profiles" below

## Additional Configuration Profiles

This section describes some additional profiles we have available for the
PanCancer project.  First, please see the general documentation above and the
README for Bindle, the tool we use to build these clusters using
Vagrant. This will walk you through the process of using this software.  This
tool allows us to create clusters in different cloud environments using a
common set of configuration scripts.  We have used this project to prepare two
different profiles, one for building clusters of VMs and another for single,
stand-alone VMs.  In addition, each of those can optionally install our
reference BWA (and potentially other) workflows.  This latter process can be
very time consuming so that is why we provide a profile with and without the
workflow(s) pre-installed.

### Cluster Without Workflows

In this environment we create a cluster of VMs but it does not have any
PanCancer workflows pre-installed.  This saves provisioning runtime, which can
be as short as 20 minutes, and gives you flexibility to install
newer/alternative/custom workflows.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment, see docs above and the README for Bindle
    perl vagrant_cluster_launch.pl --use-openstack

### Cluster With BWA Workflow

In this environment we create a cluster of VMs with the PanCancer BWA Workflow
2.0 installed. This process can take ~1.5 hours depending on your connection to
the storage site for the workflow (it is a large workflow).

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.bwa_workflow.seqware.install.sge_cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment, see docs above and the README for Bindle
    perl vagrant_cluster_launch.pl --use-openstack

### Single Instance without Workflows

In this environment we create a single VM but it does not have any PanCancer
workflows pre-installed.  This saves provisioning runtime which can be as short
as 20 minutes and gives you flexibility to install newer/alternative workflows.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_node.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment, see docs above and the README for Bindle
    perl vagrant_cluster_launch.pl --use-openstack

### Single Instance with Workflows

In this environment we create a VM with the PanCancer BWA Workflow 2.0 installed.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.bwa_workflow.seqware.install.sge_node.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment, see docs above and the README for Bindle
    perl vagrant_cluster_launch.pl --use-openstack

## Cloud-Specific Notes

Each cloud used for PanCancer will be slightly different.  This section covers
information that is particular to each.

### Notes for the EBI Embassy Cloud (vCloud)

The Embassy Cloud at EBI uses vCloud.  The Vagrant vCloud plugin has limited
functionality and, therefore, only single nodes can be launched there.

### Notes for BioNimbus PDC2 (OpenStack)

BioNimbus uses OpenStack and the Vagrant OpenStack plugin is quite stable however the PDC2 environment is in flux. You
can launch VM clusters or single nodes.

When you launch the cluster you need to do the following differently from the examples above:

    # install the open stack vagrant plugin
    $ vagrant plugin install vagrant-openstack-plugin
    # make sure you apply the rsync fix described in the README.md

    # example launching a host 
    $ perl vagrant_cluster_launch.pl --use-openstack --working-dir target-os-1 --config-file vagrant_cluster_launch.json

There are several items you need to take care of post-provisioning to ensure you have a working cluster:

* generate your keypair using the web conole (or add the public key using command line tools: "nova keypair-add brian-pdc-3 > brian-pdc-3.pem; chmod 600 brian-pdc-3.pem; ssh-keygen -f brian-pdc-3.pem -y >> ~/.ssh/authorized_keys"). 
* make sure you patch the rsync issue, see README.md for this project
* you need to run SeqWare workflows as your own user not seqware. This has several side effects:
    * when you launch your cluster, login to the master node
    * "sudo su - seqware" and disable the seqware cronjob
    * make the following directories in your home directory: provisioned-bundles, released-bundles, crons, logs, jars, workflow-dev, and .seqware
    * copy the seqware binary to somewhere on your user path
    * copy the .bash_profile contents from the seqware account to your account 
    * copy the .seqware/settings file from the seqware account to your account, modify paths
    * change the OOZIE_WORK_DIR variable to a shared gluster directory such as /glusterfs/data/ICGC1/scratch, BioNimbus will tell you where this should be
    * create a directory on HDFS in /user/$USERNAME, chown this directory to your usesrname
    * copy the seqware cronjob to your own user directory, modify the scripts to have your paths, install the cronjob
    * install the workflow(s) you want, these may already be in your released-bundles directory e.g. "seqware bundle install --zip Workflow_Bundle_BWA_2.2.0_SeqWare_1.0.13.zip"
    * probably want to manually install the BWA workflow rather than via provisioning so can install as your user (or you need to update the SeqWare metadb to point to the right place).

    update workflow set current_working_dir =  '/glusterfs/netapp/homes1/BOCONNOR/provisioned-bundles/Workflow_Bundle_BWA_2.2.0_SeqWare_1.0.13' where workflow_id = 50;

After these changes you should have a working SeqWare environment set to run workflows as your user.

### Notes for OICR (OpenStack)

OICR uses OpenStack internally for testing and the Vagrant OpenStack plugin is
quite stable.  The cluster is not available to the general PanCancer group.

* generate your keypair using the web conole 
* make sure you patch the rsync issue, see README.md for this project

Here are some difference from the docs above:

    # install the open stack vagrant plugin
    $ vagrant plugin install vagrant-openstack-plugin

    # example launching a host 
    $ perl vagrant_cluster_launch.pl --use-openstack --working-dir target-os-1 --config-file vagrant_cluster_launch.json

Also note, here are the additional things I had to do to get this to work:

* I absolutely had to use float IP addresses for all nodes. Without the float IPs addresses the nodes could not reach the Internet and provisioning failed.
* I had to apply the patch to the folder sync object in Vagrant (see this project README). Otherwise the sync of /vagrant failed on the provisioning failed.  Note, this is required by Vagrant >= 1.4.x
* I used the "seqware" network
* I used the "SoftEng" tennant
* see our internal wiki for more settings

### Notes for Annai Systems (BioComputeFarm)

Annai provides an OpenStack cluster that works quite well.  You can use it for
both nodes and clusters.

### Notes for Amazon (AWS)

OICR uses AWS internally for testing and the AWS Vagrant plugin is quite
stable. The cluster is available for any PanCancer user but is not officially
part of the Phase II activities.

Some issues I had to address on Amazon:

* some AMIs will automount the first ephemeral disk on /mnt, others will not. This causes issues with the provisioning process. We need to improve our support of these various configurations. Use m1.xlarge for the time being.
* the network security group you launch master and workers in must allow incoming connections from itself otherwise the nodes will not be able to communicate with each other

### Notes for Barcelona (VirtualBox)

Cloud are not available for both of these environments.  Instead, please use
VirtualBox to launch a single node and then use the "Export Appliance..."
command to create an OVA file.  This OVA can be converted into a KVM/Xen VM and
deployed as many times as needed to process production data.

