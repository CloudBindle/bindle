## About Bindle

Bindle is a wrapper around [Vagrant](http://www.vagrantup.com/) and [Ansible](http://www.ansible.com/) for launching single node and clustered VMs on VirtualBox, Vcloud, AWS, and OpenStack.

Vagrant itself is used to launch the VMs while Ansible is used to provision them. Although Ansible is able to spin up VM's as well, it is not able to spin up machines on all platfroms. In particular Vagrant is able to work with vCloud where Ansible is not. 

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

Install dependencies (our install script is in ansible):

    sudo apt-get install git
    sudo apt-get install python-software-properties
    sudo add-apt-repository ppa:rquillo/ansible
    sudo apt-get update
    sudo apt-get install ansible
    git clone https://github.com/CloudBindle/Bindle.git
    cd Bindle 
    ansible-playbook -i install/inventory install/site.yml 
   
Note: Ansible is a very actice project and we have experienced compatibility issues between playbooks and versions of Ansible. Our playbooks are made to work with Ansible [version 1.6.10](https://seqwaremaven.oicr.on.ca/artifactory/simple/seqware-dependencies/ansible/ansible/1.6.10-precise/ansible-1.6.10-precise.deb). 

### Installing with Virtual Box

Install VirtualBox from [Oracle](https://www.virtualbox.org/) which will let you launch a local node or cluster of virtual machine nodes on your desktop or local server.

## Configuration Profiles

Since this Vagrant wrapper can be used for many different projects based on the
Bash shell scripts used to configure the hosts, we included several example
configuration templates in:

    templates/config

A configuration file will be moved to ~/.bindle upon installation. Parameters are explained in each config. 

There are two types of sections. there is the default section, where you will put most of the configuration settings. And then there are custom blocks. Upon launching a cluster parameters in the custom block will overwrite the default configurations. 

## Base Box requirements

### RAM and CPU Core Requirements

The short answer is make sure your machine (local VM, Amazon instance type,
etc) has at least 2 cores and 12G of RAM. You can certainly use less but our
SeqWare tutorials on http://seqware.io will not work properly. If you're using
Bindle to build environments for a non-SeqWare project then the memory
requirements are set by you.

The SeqWare "HelloWorld" example workflow will schedule using 8G of RAM.  So
please make sure you launch on a machine instance type (AWS, Google Cloud, etc)
with at least 12G of RAM.  For VirtualBox, you should do the same. 

## Launching a Cluster

The wrapper script that controls the system is the launcher script:

    perl bin/launch_cluster.pl --config=aws ----custom-params=<block-name> 

"block-name" is optional and indicates the block or blocks that you would like to use to overwrite the default settings.

## Terminating a Cluster

To destroy a cluster, simply run the following command:

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

Every node launched by launch_cluster.pl has it's own log file that you can view (or watch during cluster building).  Take a look inside the directory specified in the --working-dir option.  There you should see a .log file for each server being launched (for a cluster) or just master.log if you launched a node.  You can use "tail -f <logname>" to watch the progress of building your VMs.

### Re-provisioning VMs

Note that Ansible playbooks should be designed to run idempotently (and Ansible provides many tools to aid in this). Therefore, it should be possible to re-run the Ansible steps for development purposes or to test an environment for any major issue. For this purpose Bindle has also been made to run idempotently. Bindle first checks to see if the folders have been created. If they exist it assumes Vagrant has already created the VMs. If this is true Bindle skips ahead to re-provisioning whith the modified Ansible playbook

## AWS - Regions and Availability Zones

In order to specify regions and zones, c templates support two variables AWS\_REGION and AWS\_ZONE. By default, we provision in us-east-1 and randomly across zones. You can specify one or the other. For example, to provision in us-east-1 in zone a: 

    aws_region=us-east-1
    aws_zone=a,

## AWS - Additional EBS Space

In order to add extra EBS volumes across the board, use the following syntax in order to provision a 400 and 500 GB volume attached to each node:

    aws_ebs=400,500

## Interacting with the VM(s)

Once the launch_cluster.pl script finishes running you will have one or more VM instances running on a given cloud or local VM environment. [Vagrant](http://vagrantup.com) provides functions for interacting with the generated VMs. Information used to lanch the VM's can ve found in target deirecrtories' "Vagranfile"(s).

Here's a quick overview:

1. cd to your target directory, in this case sge
   * cd target/sge
2. You will see directories for each VM, such as master
   * cd master
3.once in these directories you can issue Vagrant commands
   * check the status of the VM
       * vagrant status
       * vagrant suspend
       * vagrant resume
       * vagrant halt
       * vagrant up (start /restart VM)
       * vagrant ssh (shell into machine)
       * vagrant ssh-config (get VM network information)
       * vagrant destroy

*Do not forget to shut down your instances before removing the directory!*

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

    VAGRANT_LOG=DEBUG

## Development

We are under active development. Feel free to contribute to the code base.

The project follows [HubFlow](http://datasift.github.io/gitflow/) pragma for development. The working branch is "develop".  If you need to make changes work on a feature branch and make a pull request to another developer when ready to merge with develop.  See the HubFlow docs above for a detailed description of this process.

## TODO

The list of TODO items (some of which are out-of-date):

* need to script the following for releasing AMIs: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html
* need to find way of displaying colour on stdout during Ansible play but suppress colour while saving to log
