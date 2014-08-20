## Integrating Jenkins with Bindle Test Framework Tutorial

This is our SOP on how one can integrate the Bindle Tester with Jenkins. This approach establishes continous integration for Bindle which can be very useful while it is undergoing development. Continous Integration is a development practise that requires developers to integrate code into a shared repository several times a day. Each check-in is then verified by an automated build. Currently, we are examining code changes only for the develop and release branches and also watching out for pull requests. 

### Use Cases
One use case for integrating Jenkins with Bindle Tester is to detect problems earlier and locate them easily since we know what code changes has caused this problem. Another use case is that it significantly reduces the time taken to manually test bindle. 

###Summary of the steps

Please note that some of the steps described here can be skipped. For example, if you already have a functioning jenkins slave for bindle and simple want to create a new project or modify the configuration of a jenkins project, then you can skip the first step.

* Launch an instance from Openstack's web console and call it something like "bindle_jenkins_slave_1". Then, provision the slave node via seqware-sandbox
  * Clone "seqware-sandbox" and navigate to seqware-sandbox/ansible_jenkins_slaves
  * Change the inventory to include your host's ip address under both "jenkins" and "jenkins_bindle"
  * Run the ansible script(site.yml)
* ssh into your jenkins node and verify the following items are installed properly:
  * Vagrant 1.6.3
  * vagrant-aws and vagrant-openstack-plugin 
  * Bindle dependencies
  * Bindle Tester dependencies
* Log into Jenkins console by writing "jenkins" in the address bar of a web browser and either create a new project or modify an existing project
* Click on the project and navigate to the "configure" screen
* Fill in the configuration and save it!
* Clone Bindle and copy tester/config_templates to ~/.bindle/test_framework_configs
  * Fill in all the required information of the config_files located at ~/.bindle/test_framework_configs
* You are fully set up and can run a build by making code changes to the particular branch you chose to set up or pressing the build now button in jenkins console!


### Detailed Example - Configuring Jenkins to monitor the develop branch 
Let's go through the steps described above in detail by going through what we had to do to add the monitoring of the develop branch with jenkins. That way, in furture, if you need to make changes or add the monitoring of another branch, you can refer to this example as a guide. Please note that this example shows you how to do this from scratch. That is, it includes steps where you need to get a node and configure it as a jenkins slave. If you already have that done, feel free to skip those steps.

#### Step 1 - Get a launcher host for jenkins
You can get a launcher host for jenkins by launching an instance from OICR openstack's web console (https://sweng.os.oicr.on.ca/horizon/). Please make sure you use a keypair that can be shared with others so that others can get access to the jenkins node as well. The recommended instance type for this launcher would be "m1.xlarge" since the server needs to be pretty powerfull so that it has the ability launch and provision multiple clusters concurrently. Also, give a descriptive name to the node (ex. bindle_jenkins_slave_1) so that it is recognizable by others as well. This will be the node that will be used by jenkins to launch and provision clusters using Bindle and testing them using the Bindle Tester.

#### Step 2 - Provision the slave node via seqware-sandbox
Next, we need to provision the launcher host by using an existing ansible playbook that creates jenkins slave nodes and also installs the required dependencies to it. Before we dive into the usage of ansible playbook, please ssh into the launcher host you created and copy the contents of you pub key located at "~/.ssh/id_rsa.pub". Once you have that done, follow this:

     # clone seqware-sandbox on your computer
     git clone https://github.com/SeqWare/seqware-sandbox.git
     # navigate to seqware-sandbox/ansible_jenkins_slaves
     cd seqware-sandbox/ansible_jenkins_slaves
     # Add your public keys to files/public_keys and edit the listed keys
     mkdir files/public_keys
     # Add the public key of your launcher host here and save it
     vim files/public_keys/jenkins
     # Delete the "Copy maven configuration" task from site.yml if it hasn't been done already
     vim site.yml
     # Change the inventory to include your host's ip address under both "jenkins" and "jenkins_bindle". 
     # Follow the same format as the ones that already exist. 
     # Comment the other hosts out since you only want to run the playbook for your launcher host
     vim jenkins_seqware_inventory
     # run the playbook
     ansible-playbook -i jenkins_seqware_inventory site.yml

#### Step 3 - Verify all the dependencies are installed on your jenkins slave
Next, we need you to ssh into the bindle slave you created and make sure all the dependencies are installed correctly. We need to verfiy that all vagrant is installed properly and is the correct version used by Bindle(1.6.3). Then, we need to make sure all the vagrant cloud plugins used by Bindle Tester are installed properly(vagrant-aws and vagrant-openstack-plugin). We also need to make sure all the dependencies for Bindle and Bindle Tester are installed.

     # verify all the vagrant components are installed
     vagrant -v
     # should have vagrant-aws and vagrant-openstack-plugin in this list
     vagrant plugin list
     # verify all the bindle dependencies are installed correctly
     git clone https://github.com/ICGC-TCGA-PanCancer/pancancer-info.git
     cd Bindle
     # this command should execute without any errors
     perl -c bin/launcher/launch_cluster.pl
     # verify all the Bindle Tester dependencies are installed correctly
     perl -c tester/bin/bindle_test_framework.pl
     cd ..
     rm -rf Bindle

If something isn't installed, please do install the required component. You can take a look at Bindle and Bindle Tester readme to figure out how to install vagrant/vagrant plugins and the required perl modules. Then, verify the compenents again before moving on to the next step.

#### Step 4 - Configuring the project with jenkins
Finally, we need to add and configure a jenkins job. After that, jenkins will automatically detect code changes in the develop branch and generate an html page with the test results for every build. 

1. Navigate to jenkins web console by typing "jenkins" in the address bar of your web browser
2. Create a jenkins project if you don't have one already by navigating to New Item
 * Give it a useful name (Ex. bindle-develop) and you can either choose Build a free-style software project or copy from an existing item
3. Navigate to the project page and click "Configure" to bring up configuration screen. If you don't see any Configure option, you might have have the required permissions.
4. To get help in filling out the configuration, please take a look at one of the existing projects for bindle or seqware
 * An excellent project would be "bindle-develop" if you want to add branch monitoring to jenkins or "bindle-pullrequest" to add pull request monitoring.

Now, you should have a functional monitoring system where Bindle Tester will get invoked whenever a change has been committed to the branch or whenever a pull request has been made, depending on what you are wanting to do with jenkins. Then, it will report you with the test results at the end of every build.
    
