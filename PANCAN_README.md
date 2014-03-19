# TCGA/ICGC PanCancer - Cluster Launch SOP

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

#### Steps

* decide on cloud environment and request an account
* download and install:
** SeqWare-Vagrant
** Vagrant
** Vagrant plugins and/or VirtualBox
* copy and customize the SeqWare-Vagrant template of your choice with your appropriate cloud settings
* launch your cluster or node using vagrant_cluster_launch.pl
* ssh into your cluster
* launch SeqWare workflow(s) and monitor their results
* the previous step can be automated with a decider

#### Detailed Steps - Annai BioComputeFarm Example with PanCancer BWA-Mem Workflow 2.0

First, you need to get a BioComputeFarm account, email Annai systems and they will work with you for this.

Next, you can launch a "launcher" host. This is your gateway to the system and allows you to launch clusters of nodes that actually do the processing.  It also is the location to run the "decider" that will schedule the BWA workflow running on your many clusters in this cloud.

# launch a "launcher" node via the GUI at 

# you may need to install some dependencies including git
# TODO: we need to zip up the release
ubuntu@brian-launcher:~$ git clone https://github.com/SeqWare/vagrant.git


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

## Notes for EBI's Embassy Cloud (vCloud)

The Embassy Cloud at EBI uses vCloud.  The Vagrant vCloud plugin has limited
functionality and, therefore, only single nodes can be launched there.

## Notes for BioNimbus (OpenStack)

BioNimbus uses OpenStack and the Vagrant OpenStack plugin is quite stable. You
can launch VM clusters or single nodes.

## Notes for OICR (OpenStack)

OICR uses OpenStack internally for testing and the Vagrant OpenStack plugin is
quite stable.  The cluster is not available to the general PanCancer group.

## Notes for Amazon (AWS)

OICR uses AWS internally for testing and the AWS Vagrant plugin is quite
stable. The cluster is available for any PanCancer user but is not officially
part of the Phase II activities.

