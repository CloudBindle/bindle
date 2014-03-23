# TCGA/ICGC PanCancer - Workflow Development Node Launch SOP

This is our SOP for how to launch clusters/nodes using SeqWare-Vagrant
specifically for use by the TCGA/ICGC PanCancer project.  In addition to
providing production cluster environments for analyzing samples on the clouds
used by the PanCancer project, the SeqWare-Vagrant process can also be used to
create workflow development environments.

## Use Cases

There are really two use cases for this technology by the PanCancer project.
First, to create a production environment for running analytical workflows for
PanCancer.  Second, to create a workflow development environment for creating
new workflows for the project. In this guide we will focus on the second.

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


