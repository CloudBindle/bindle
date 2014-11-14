## About Bindle

Bindle is a wrapper around [Vagrant](http://www.vagrantup.com/) and [Ansible](http://www.ansible.com/) for launching single node and clustered VMs on VirtualBox, Vcloud, AWS, and OpenStack.

Vagrant itself is used to launch the VMs while Ansible is used to provision them.

Variables are passed from bindles configuration files ( located: ~/.bindle) to Ansible through a JSON file for each VM.  

Bindle can be used for is building both Hadoop and GridEngine-based clusters on a variety of cloud environments. 

In separate repositories, secondary provisioning Ansible scripts are provided that setup a single-node or multi-node SeqWare cluster configured to use the Oozie workflow engine. Since this Vagrant wrapper is fairly generic the same process can be adapted to build other cluster types to serve other projects.  

You can also base anything that needs a Hadoop and/or GridEngine cluster of machines created on a variety of cloud platforms on our Ansible playbooks. Ansible playbooks are included by specifying the the path to the playbook with the parameter 'ansible_playbook' in the  bindle configuration files.

## Sister Repositories

* [SeqWare - seqware_bag](https://github.com/SeqWare/seqware-bag) (with Oozie-Hadoop and/or Oozie-SGE backends) and associated SeqWare projects (WebService, MetaDB, etc)
* [TCGA/ICGC PanCancer Project -pancancer_bag](https://github.com/ICGC-TCGA-PanCancer/pancancer-bag) for PanCancer specific provisioning

### PanCancer Architecure Installatiion 

* [Architecture Setup](https://github.com/ICGC-TCGA-PanCancer/architecture-setup) scripts have been created to install Bindle, [seqware_bag](https://github.com/SeqWare/seqware-bag) and [pancancer_bag](https://github.com/ICGC-TCGA-PanCancer/pancancer-bag).

## Installation

*  Install Ansible: bash install-ansible
*  Install Dependencies: run playbook
   
Note: Ansible is a pretty fast moving project and we tested against [version 1.6.10](https://seqwaremaven.oicr.on.ca/artifactory/simple/seqware-dependencies/ansible/ansible/1.6.10-precise/ansible-1.6.10-precise.deb). 

run 'perl -c bin/launch_cluster.pl' to make sure all perl modules are installed in your environment

It should exit without an error message. 
For detailed explanation on setting up a launcher and launching clusters from that, please refer to
the [Pancancer Cluster Launch ReadMe](https://github.com/SeqWare/vagrant/blob/develop/PANCAN_CLUSTER_LAUNCH_README.md)

### Installing with Virtual Box

Install VirtualBox from [Oracle](https://www.virtualbox.org/) which will let you launch a local node or cluster of virtual machine nodes on your desktop or local server.

## Configuration Profiles

Since this Vagrant wrapper can be used for many different projects based on the
Bash shell scripts used to configure the hosts, we included several example
configuration templates in:

    ./templates/config

A configuration file will be moved to ~/.bindle upon installation.

### Configureation Parameters

#### Platform Block
The platform section is used for sepcifying platform specfic information. 


Let us go through the parameters that might confuse you when you are filling the config file. I will not be going 
through the most obvious parameters (ie. user, apikey, etc):

    [platform]
    # can be either openstack(os) or aws or vcloud
    type=openstack/aws/vcloud
     
    # asks for the name of your pem file. Please make sure you have the pem file under ~/.ssh on your launcher host
    ssh_key_name=ap-oicr-2
    
    # asks for the type of node you want to launch (m1.small, m1.medium, m1.xlarge, etc)
    instance_type=m1.xlarge
    
    # This list is to indicate the devices you want to use to setup gluster file system on.
    # To find out the list of devices you can use, execute “df | grep /dev/” on an instance currently running on the same platform. 
    # DO NOT use any device that ends with "a" or "a" and a number following it(sda or sda1) because these are used for root partition
    # Also, if you don't want to use any devices to set up gluster, please keep the value empty (gluster_device_whitelist=''). You need to do that when you are dealing with a single node cluster or when you have no devices to work with
    # For AWS, when you create an EBS volume by using --aws-ebs parameter, it creates an "sdf" device, so specify "f" in your list gluster_devices
    # Now, if you want to use "sdb/xvdb" and "sdf/xvdf" then your list should look like the following:
    gluster_device_whitelist='--whitelist b,f'

    # this parameter indicates the path you want to use to set up gluster IF you don't have any devices to work with
    # If you don't want to use directories, simply leave this parameter empty (gluster_directory_path=''). This should be the case for single node clusters
    # If you don't have devices, include the path and folder name that can be used instead to set up the volumes for a multi-node cluster: 
    gluster_directory_path='--directorypath /mnt/volumes/gluster'
    
The other platform specific parameters are self explanatory. In the config file, there is a "fillmein" value which indicates that you
defintely have to fill those in to have bindle working properly. The others are deafult values that you may use unless otherwise stated.

#### Cluster Specific Information

This information exists in small blocks name cluster1, cluster2, etc. These blocks contain essential information such as number of nodes,
target_directory, the json_template file path, and floating ips which is specific to OpenStack only since the other 
environments have the ability to generate the floating ips on their own.
    
Please note that you can create a new cluster by copy-pasting the existing cluster1
block and modifying the configs for it or you can simply modify cluster1 configs and use that.
Feel free to change the number of nodes (min 1, max recommended 11). Please note that 
if the number of nodes is 1, it means that there will be 1 master and 0 worker nodes. 
Also, you need the same number of floating ips as the number of nodes if you are working with openstack.
In addition, the list is separated by a comma and there is no need to put this list in quotations.
An example cluster block will look something like this:

    # Clusters are named cluster1, 2, 3 etc.
    # When launching a cluster using launch_cluster.pl
    # use the section name(cluster1 in this case) as a parameter to --launch-cluster
    [cluster1]
   
    # this includes one master and four workers
    number_of_nodes=4
   
    # specific to Openstack only; must have 4 floating ips since we need 4 nodes
    floating_ips= 10.0.20.123,10.0.20.157,10.0.20.135,10.0.20.136
   
    # this specifies the output directory where everything will get installed on the launcher
    target_directory = target-os-2
   
To use a specific cluster block, you need to use the section name of that block as a parameter to --launch-cluster when you
are running the launch_cluster perl script.

### Configuration for VirtualBox

Please note for VirtualBox, you will need to use the old configuration technique:
    
   fill in the apropriat fields in ~/.bindle/virtualbox.cfg    

You can fill in the required information and move on to the next step.

If you use the template recommended above you will have a 1 node Hadoop cluster
(with Mapred, HDFS, HBase, Oozie, Hue, etc installed) along with the SeqWare
software stack installed.  This environment should be ready for use with out
Getting Started Guides for this project.

## RAM and CPU Core Requirements

The short answer is make sure your machine (local VM, Amazon instance type,
etc) has at least 2 cores and 12G of RAM. You can certainly use less but our
SeqWare tutorials on http://seqware.io will not work properly. If you're using
Bindle to build environments for a non-SeqWare project then the memory
requirements are set by you.

The SeqWare "HelloWorld" example workflow will schedule using 8G of RAM.  So
please make sure you launch on a machine instance type (AWS, Google Cloud, etc)
with at least 12G of RAM.  For VirtualBox, you should do the same.  Our default
profile for VirtualBox requests 12G of RAM and 2 cores.  If you need to change
this setting please see the --vb-ram and --vb-cores options that let you
override the memory/core requirements in VirtualBox ONLY.  Keep in mind for AWS
and other clouds the RAM and Cores are determinted by the instance type you
choose not by the --vb-ram and --vb-cores options.

## Running the Cluster Launcher

The wrapper script that controls the system described above is called
"bin/launcher/launch\_cluster.pl". 

Please note that a detailed explanation of the cluster launching process
for virtual box is located [here](https://github.com/SeqWare/pancancer-info/blob/develop/docs/workflow_dev_node_with_bindle.md)
A detailed explanation of the cluster launching process for other environments 
is located [here](https://github.com/SeqWare/pancancer-info/blob/develop/docs/prod_cluster_with_bindle.md)

Examples of launching in different environments include:

    # for AWS
    perl bin/launch_cluster.pl --config=aws --cluster <cluster-name> 
    # for OpenStack
    perl bin/launch_cluster.pl --config=openstack --cluster <cluster-name>

"clustername" represents the cluster block you want to run from the config file (Ex: cluster1).

## Destroying the Clusters

The script that takes care of the process required to terminate a cluster is located at 
"bin/destroy_cluster.pl". To destroy a cluster, simply run the following command:

     # assumes you are in the Bindle directory
     perl bin/destroy_cluster.pl --cluster-name <target-dir>
     
The target-dir is the directory path of your cluster folder(Ex. target-aws-1/). This will remove
the cluster from the appropriate environment but it is advised to check the web interface to make sure
that the nodes are deleted.

## Persistance of Ephemeral Disks - AWS

Amazon instances provisioned using Bindle store information such as file inputs and outputs, the /home directory, and the Oozie working directory in /mnt which is normally backed by ephemeral drives. If you wish them to persist (when rebooting instances or distributing images) you will need to mount them on an EBS volume instead. Follow the steps below to get an AMI image up and running with a single node instance.

### Starting with an EBS volume

First, you will want to start by requesting an instance with disabled ephemeral drives and everything mounted on a single EBS volume. 
To do this, you will want to add the following line into your aws.cfg

        ebs_vols = "aws.block_device_mapping = [{ 'DeviceName' => '/dev/sda1', 'Ebs.VolumeSize' => 1000 },{'DeviceName' => '/dev/sdb', 'NoDevice' => '' }]"

This creates a root drive with 1000GB of space and disables the single ephemeral drive that would otherwise would have been auto-mounted by Amazon at /dev/sdb that would handle the /mnt directories. Run Bindle normally otherwise. 

### Creating the AMI image

1. Log onto the Amazon Web Console and navigate to EC2 -> Instances -> Instances
2. Right click on the single node instance and select "Create Image"
3. Give it an appropriate Image name(Ex. Seqware\_1.1.0-alpha.5\_Bindle\_1.2) 
4. If you are using [youxia](https://github.com/CloudBindle/youxia)'s deployer, you should record ephemeral disks as needed in the image configuration. While Amazon treats this information as a suggestion (see below), youxia will re-specify this information at launch time to ensure that the desired number of ephemeral disks is available. It is safe to over-specify (i.e. specify four ephemeral disks even if only two are required).    
5. Click Create Image! 

For more information on Amazon block mapping, see [this](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/block-device-mapping-concepts.html). The specific sections that can be problematic is:

    Depending on instance store capacity at launch time, M3 instances may ignore AMI instance store block device    
    mappings at launch unless they are specified at launch. You should specify instance store block device mappings 
    at launch time, even if the AMI you are launching has the instance store volumes mapped in the AMI, to ensure 
    that the instance store volumes are available when the instance launches. 

You should now have a functioning AMI. The next step would be to launching an instance from the AMI image and running the HelloWorld Workflow to make sure it works. The guide to creating an instance from an AMI image is located below.

### Launching a single node instance from an AMI image

1. Log onto the Amazon Web Console and navigate to EC2 -> Images -> AMI
2. Choose the appropriate AMI and select Launch
3. Choose the Instance Type and then, navigate to step 4. In this step, remove the Instance Store 0 volume from the list if it exists.
4. Click Review and Launch and you are done!

You now have a workflow development environment and a place where you can run workflows!

## Logging

Every node launched by launch_cluster.pl has it's own log file that you
can view (or watch during cluster building).  Take a look inside the directory
specified in the --working-dir option.  There you should see a .log file for
each server being launched (for a cluster) or just master.log if you launched a
node.  You can use "tail -f <logname>" to watch the progress of building your
VMs.

### Re-running Ansible

Note that Ansible playbooks should be designed to run idempotently (and Ansible provides many tools to aid in this). Therefore, it should be possible to re-run the Ansible steps for development purposes or to test an environment for any major issue. For this purpose Bindle has also been made to run idempotently. Bindle first checks to see if the folders have been created. If they exist it assumes Vagrant has already created the VMs. If this is true Bindle skips ahead to re-provisioning whith the modified Ansible playbook

    perl bin/launch_cluster.pl --config=<config-name>  --cluster=<cluster-block-name>
    
After running the launcher script Ansible commands are generated and stored in the target directories. At this point, it is possible to run these ansbible command directly. 

## AWS - Regions and Availability Zones

In order to specify regions and zones, c templates support two variables AWS\_REGION and AWS\_ZONE. By default, we provision in us-east-1 and randomly across zones. You can specify one or the other. For example, to provision in us-east-1 in zone a: 

    aws_region=us-east-1
    aws_zone=a,

## AWS - Additional EBS Space

In order to add extra EBS volumes across the board, use the following syntax in order to provision a 400 and 500 GB volume attached to each node:

    aws-ebs=400,500


## Interacting with the VM(s)

Once the launch_cluster.pl script finishes running you will have one or more VM instances running on a given cloud or local VM environment. [Vagrant](http://vagrantup.com) provides functions for interacting with the generated VMs. Information used to lanch the VM's can ve found in target deirecrtories' "Vagranfile"(s).

Here's a quick overview:

    # first, cd to your target directory, in this case target-sge
    cd target-sge
    # you will see directories for each VM, such as master
    cd master
    # once in these directories you can issue Vagrant commands
    # check the status of the VM
    vagrant status
    # suspend
    vagrant suspend
    # resume
    vagrant resume
    # shutdown the VM
    vagrant halt
    # restart the VM
    vagrant up
    # ssh to the machine
    vagrant ssh
    # for ssh information
    vagrant ssh-config
    # terminate and remove the VM
    vagrant destroy

*Do not forget to shut down your instances!*


## Veewee Installation and Usage Instructions (Mac)

VeeWee can be used to create CentOS base boxes 

1. Get veewee from here, as follows:
    `git clone https://github.com/jedi4ever/veewee.git`

2. Install RVM as follows:
    ```Shell
    mkdir -p ~/.rvm/src && cd ~/.rvm/src && rm -rf ./rvm && \
    git clone --depth 1 git://github.com/wayneeseguin/rvm.git && \
    cd rvm && ./install
    ```

3. Add an RVM invocation and veewee alias to the end of your .profile or .bash_profile, .bashrc or .zshrc file, as follows:
    ```Shell
    if [[ -s $HOME/.rvm/scripts/rvm ]]; then
      source $HOME/.rvm/scripts/rvm;
    fi
    alias veewee='bundle exec veewee'
    ```

4. Install the appropriate version of Ruby:
    `rvm install ruby-1.9.2-p320`

5. Navigate to the veewee directory. This should automatically invoke RVM.

    `cd veewee`

    *NOTE:* If asked to upgrade from using an .rvmc file to a .ruby-version file, do *not* do this.

6. Copy or symlink the Seqware-veewee folder from SeqWare/vagrant into the veewee directory:
    `ln -s *[PATH TO BINDLE]*/SeqWare-veewee ./definitions/SeqWare-veewee`

7. Edit veewee's "definition.rb" file, and comment out the following three scripts:
    chef.sh, puppet.sh, ruby.sh


## Debugging

If you need to debug the spinning up of VM's a problem set the VAGRANT_LOG variable e.g.:

    VAGRANT_LOG=DEBUG perl bin/launch_cluster.pl --config=aws --cluster=cluster1

## Development

We are under active development. Feel free to contribute to the code base.

The project follows [HubFlow](http://datasift.github.io/gitflow/) pragma for development. The working branch is "develop".  If you need to make changes work on a feature branch and make a pull request to another developer when ready to merge with develop.  See the HubFlow docs above for a detailed description of this process.

## TODO

The list of TODO items (some of which are out-of-date):

* need to script the following for releasing AMIs: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html
* need to find way of displaying colour on stdout during Ansible play but suppress colour while saving to log
