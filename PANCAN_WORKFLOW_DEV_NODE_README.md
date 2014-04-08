# TCGA/ICGC PanCancer - Workflow Development Node Launch SOP

This is our SOP for how to create a SeqWare workflow development environment
for use with the PanCancer project. Since the environment also contains
GridEngine and Hadoop it may be useful for creating workflows using those tools
directly however the focus will be on SeqWare development. In this SOP we use
[VirtualBox](https://www.virtualbox.org/) to run a local VM which has a shared
folder with your desktop. This lets you develop in an IDE on your host
operating system and then compile and debug the workflow on the virtual
machine.

## Use Cases

There are really two use cases for this technology by the PanCancer project.
First, to create a production environment for running analytical workflows for
PanCancer (see the SOP for that activity).  Second, to create a workflow
development environment for creating new workflows for the project. In this
guide we will focus on the second.

### Build a Workflow Development Environment

Bindle can be used to create a workflow development environment that
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
across all the various Bindle-created environments. SeqWare workflows
also integrate with metadata tracking tools and deciders, allowing for
automated triggering.  This allows us to detect new samples in Phase II, launch
clusters using Bindle, and then automatically run workflows on those
environments.

You can find more information on how to build SeqWare workflows and use the
SeqWare tools at our project website http://seqware.io.

## Steps

* you will be working locally using VirtualBox, make sure you have a Linux or Mac available to work on with 16G of RAM
* download and install:
    * Bindle
    * Vagrant
    * VirtualBox
* copy and customize the Bindle template of your choice (a single node only, do not use a cluster profile)
* launch your development node using vagrant_cluster_launch.pl, select "--use-virtualbox" 
* ssh into your node
* Vagrant will automatically create a vagrant directory ("/vagrant" on the VM and within your "working_dir/master" dir) that is shared between your host and the VM 
* create new SeqWare workflows in this "working_dir/master" directory, please see the Developer Getting Started Guide at http://seqware.io
* you can compile SeqWare workflows on your local computer or on the VM
* launch SeqWare workflow(s) on your VM to test them and monitor their results
* package your workflow as a zip bundle (see Developer guide) once your testing is complete, this can be distributed to other clouds for installation and execution in Phase II or Phase III

## Detailed Steps Using VirtualBox Locally

The following is a detailed example showing you how to setup the workflow development environment:

### Step - Download and Install Components

These steps will be different depending on whether or not you use a Mac or
Linux host machine.  Much more information about Bindle can be found
at our GitHub site https://github.com/SeqWare/vagrant. In particular take a
look at the README.md which goes into great detail about installing and
configuring these tools.

This is an example for a Linux machine running Ubuntu 12.04. You will need to
follow a similar process if using a Mac but the detail are beyond the scope of
this document.

Note the "$" is the Bash shell prompt in these examples and "#" is a comment:

    # download and install VirtualBox
    $ wget http://download.virtualbox.org/virtualbox/4.3.8/virtualbox-4.3_4.3.8-92456~Ubuntu~precise_amd64.deb
    # sudo dpkg -i virtualbox-4.3_4.3.8-92456~Ubuntu~precise_amd64.deb

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

In the future we will provide pre-configured OVA for the development environment
to eliminate the installation tasks above. All that will be required is
VirtualBox. For now please move on to the next step.

### Step - Configuration

Now that you have Bindle and dependencies installed the next step is
to launch your local VM that will run workflows via SeqWare, launch cluster
jobs via GridEngine, or perform MapReduce jobs.

The steps below assume you are working in the bindle_1.2 directory:

    # copy the template used to setup a SeqWare single compute node for PanCancer
    # no modifications are required since you are launching using VirtualBox
    $ cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_node.json.template vagrant_cluster_launch.json

### Step - Launch a SeqWare Dev Node

Now that you have customized the settings in vagrant_cluster_launch.json the
next step is to launch a computational node. Note, each launch of a
node/cluster gets its own "--working-dir", you cannot resuse these.  Within the
working dir you will find a log for each node (simply master.log for a
single-node launch) and a directory for each node that is used by the vagrant
command line tool (the "master" directory for a single-node launch). The latter
is important for controlling your node/cluster once launched.

For VirtualBox there are two optional parameters that control memory and CPUs
used.  We recommend 12G for the RAM and 2 or more CPUs depending on what is
availble on your machine. Do not attempt to use more RAM/CPU than you have
available.

    # now launch the compute node, 12G RAM, 2 CPU cores
    $ perl vagrant_cluster_launch.pl --use-virtualbox --working-dir target-vb-1 --vb-ram 12000 --vb-cores 2 --config-file vagrant_cluster_launch.json

You can follow the progress of this cluster launch in another terminal with.
Use multiple terminals to watch logs for multiple-node clusters if you desire:

    # watch the log
    $ tail -f target-vb-1/master.log

Once this process complete you should see no error messages from
"vagrant_cluster_launch.pl". If so, you are ready to use your workflow
development node.

### Step - Log In To Node/Cluster

Vagrant provides a simple way to log into a launched node.  For example:

    # log into the master node
    $ cd target-vb-1/master
    $ vagrant ssh

This will log you into the master node.  You can change user to the vagrant
user which will be used for subsequent steps or root if you need to do some
administration of the box. We use the "vagrant" user because that user owns the
/vagrant directory which is the shared filesystem with target-vb-1/master. By
using this user we can edit files via and IDE on the host computer and compile
and test the workflow as the vagrant user working in /vagrant. The vagrant user
is very similarly configured compared to the seqware user and can, essentially,
be thought of in the same way:

    # switch user to vagrant
    $ sudo su - vagrant
    # or switch user to root (not generally needed!)
    $ sudo su -

#### Step - Verify Node/Cluster with HelloWorld

Now that you have a workflow development node the next step is to launch a sample
HelloWorld SeqWare workflow to ensure all the infrastructure on the box is
functioning correctly.  Depending on the template you used this may or may not
be already installed under the seqware user account. If not, you can download a
copy of the workflow and install it yourself following our guides on
http://seqware.io (see
https://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13.zip).

    # assumes you have logged into your master node and switched to the vagrant user
    # download the sample HelloWorld workflow
    $ wget https://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13.zip
    # install the workflow
    $ seqware bundle install --zip Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13.zip
    # now run the workflow with default test settings
    $ seqware bundle launch --dir provisioned-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.13

This command should finish without errors.  If there are problems please report
the errors to the SeqWare user group, see http://seqware.io/community/ for
information about posting to our mailing list.

### Step - Create a New Workflow

At this point you now have a complete SeqWare/GridEngine/Hadoop environment for
creating and testing workflows in.  In this next step I will show you how to
create a new SeqWare workflow using Maven Archetypes.  These are templates that
create all the boilerplate for you so you can just focus on the contents of
your workflow rather than the setup of the various files and directories needed
to create a SeqWare workflow with Maven. You will work as the vagrant user
in the /vagrant directory (which is target-vb-1/master on your local desktop).
In this way both your desktop and the VM can share the workflow.

    # work in the /vagrant directory
    $ cd /vagrant

    # now create a new workflow from the Maven template
    $ mvn archetype:generate \
    -DinteractiveMode=false \
    -DarchetypeCatalog=local \
    -DarchetypeGroupId=com.github.seqware \
    -DarchetypeArtifactId=seqware-archetype-java-workflow \
    -DgroupId=io.seqware \
    -Dpackage=io.seqware \
    -DartifactId=MyHelloWorld \
    -Dversion=1.0-SNAPSHOT \
    -DworkflowVersion=1.0-SNAPSHOT \
    -DworkflowDirectoryName=MyHelloWorld \
    -DworkflowName=MyHelloWorld \
    -Dworkflow-name=MyHelloWorld

    # you can now compile that workflow
    $ cd MyHelloWorld
    $ mvn clean install

    # now test the workflow
    $ seqware bundle launch --dir target/Workflow_Bundle_MyHelloWorld* 

The above just is the start of our documentation for workflow development using
SeqWare.  Please see http://seqware.io for much more information, in particular
look at the Developer Getting Started Guide.

### Step - Modify the Workflow on Your Desktop

Now the cool part, since /vagrant on the VM and target-vb-1/master on your
desktop host computer are shared, you can use your favorite IDE to edit the
Java SeqWare workflow.  Simply fire up your IDE (for example NetBeans) and open
up the Maven workflow you created above.  In the case of NetBeans you would use
"File.../Open Project..." and navigate to the "target-vb-1/master/MyHelloWorld"
directory which should be recognized as a Maven project.  You can then modify
the Workflow Java object, workflow.ini, and other template files all from your
nice IDE interface on your desktop computer.  When you want to compile or test
the workflow you can do this on your VM which is setup for both activities.

### Step - Test and Package Your Workflow

As with the example above, you can compile and test your workflow after you make changes.  Just repeat the mvn and seqware commands above on your VM as vagrant after you make changes in your IDE on your desktop host computer:

    # you can now compile that workflow
    $ cd /vagrant/MyHelloWorld
    $ mvn clean install

    # now test the workflow
    $ seqware bundle launch --dir target/Workflow_Bundle_MyHelloWorld*

When you are happy with your workflow you can "package" it up for distribution to other sites.

    # package the final workflow
    $ seqware bundle package --dir target/Workflow_Bundle_MyHelloWorld*

On another SeqWare VM you install this bundle using:

    # install on another VM
    seqware bundle install --zip Workflow_Bundle_MyHelloWorld*.zip

The above just is the start of our documentation.  Please see http://seqware.io
for much more information, in particular look at the Developer Getting Started
Guide.

## Next Steps

Much more information can be found in the README for the Bindle
project, see https://github.com/SeqWare/vagrant

For workflow development using SeqWare we encourage you look at our extensive
documentation on http://seqware.io and post to the user list if you run into
problems.

