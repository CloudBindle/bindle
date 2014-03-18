# TCGA/ICGC PanCancer - Cluster Launch SOP

This is our SOP for how to launch clusters/nodes using SeqWare-Vagrant. It is
intended to be used to create clusters of virtual machines running in one of
several cloud environments used by the PanCancer project.  These clusters are
intended to process approximately 2,500 whole human genomes using standardized
workflows: BWA and variant calling.

## General

First, please see the general documentation on SeqWare-Vagrant, the tool we use
to build these clusters using Vagrant. This will walk you through the process
of using this software.  This tool allows us to create clusters in different cloud
environments using a common set of configuration scripts.  We have used this
project to prepare two different profiles, one for building clusters of VMs and
another for single, stand-alone VMs.  In addition, each of those can optionally
install our reference workflow.  This latter process can be very time consuming 
so that is why we provide a profile with and without the workflow(s)
pre-installed.

### Cluster without Workflows

In this environment we create a cluster of VMs but it does not have any
PanCancer workflows pre-installed.  This saves provisioning runtime which can
be as short as 20 minutes and gives you flexibility to install
newer/alternative workflows.

    # use this template, customize it
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_cluster.json.template vagrant_cluster_launch.json
    # launch, use the correct command line args for your cloud environment
    perl vagrant_cluster_launch.pl --use-openstack

### Cluster with BWA Workflow

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

## Use Cases

There are really two use 

### Build a PanCancer BWA-Mem Workflow Environment

Used for Phase II where we align 2,500 donors and Phase III where individual researchers will use this provisioning process to create environments of their 

### Build a Workflow Development Environment

## Notes for EBI's Embassy Cloud (vCloud)

## Notes for BioNimbus (OpenStack)

## Notes for OICR (OpenStack)

## Notes for Amazon (AWS)

