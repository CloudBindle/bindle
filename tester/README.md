## Table of Contents

* [About Bindle Tester](#about-bindle-tester)
* [Step by step Tutorial](#step-by-step-tutorial)
  * [Manually launching the test framework](#manually-launching-the-test-framework)
  * [Integrating the test framework with jenkins](#integrating-the-test-framework-with-jenkins)
* [Bindle Tester Dependencies](#installing)
* [Configuration Files](#configuration-files)
* [Running Bindle Tester](#running-bindle-tester)
* [Adding Tests](#adding-tests)
* [Adding Cloud Environments](#adding-cloud-environments)
* [Commit ids from the latest build that was successful](#commit-ids-from-the-latest-build-that-was-successful)
* [TODOs](#todos)

### About Bindle Tester

This project is a test framework for Bindle which is designed to test it whenever changes are made to the develop branch, release branch, or when a pull request has been made. This lets you build, provision, and test Linux virtual machines from scratch on various cloud environements (currently AWS and OICR Openstack). For more information on exactly how the build and provision process varies from doing it from vagrant directly, please refer to the Bindle README. 

This framework has been primarily constructed to follow the continous integration process and detect bugs right away once code has been pushed to this repository. This significantly reduces the amount of manual testing that need to be done to verify that bindle is provisioning the clusters correctly. How does this tool get the above job done? In short, the tool launches multiple clusters (currently single-node and two-node clusters but it can be scaled to more if required) on multiple cloud environments through bindle and then, it carries out a set of tests tailored toward each of the clusters. Based on the results, we can confirm whether or not the clusters were provisioned correctly. 

You can manually execute this project by executing the perl script under the bin folder of this directory. More on this later. However, the project has been integrated with jenkins which has the capability to automatically detect when someone makes changes to the Bindle repository. The bindle jenkins node contains all the configuration information of the different environments which need to be updated if required in order for the automated testing process of Bindle to work. This will be discussed in detail later. 

In the latest version of the script, we support automated testing on AWS and OICR openstack environments. In the near future, we will be looking into adding vCloud to the test framework as well. There will be a section which will discuss the pseudo process of how you can add a new cloud environment to this tool. The main goal of this project is minimize the long and tedious process of manual testing since provisioning a cluster itself takes about 30 minutes and testing it takes another 30 minutes. 

### What is Jenkins?
You might be wondering what Jenkins is all about because I certianly did when I first got introduced to it. For our purposes, it is an open source continous integration tool that is able to detect if there are any code changes to the repository on github and if so, then it has the ability to monitor a build system. This is the perfect way to catch errors quickly and locate them more easily. Jenkins can also provide reports and notifications to alert developers on success or on errors. So, we utilize jenkins just for this purpose; we use the test framework as the "build" and generate a html report at the end of the build which contains the test results! Some tips/tutorial I found helpful while working with jenkins:
* http://www.vogella.com/tutorials/Jenkins/article.html
* http://jenkins-ci.org/views/hudson-tutorials
* Look at the existing configuration of seqware projects that Denis has already set up or the existing bindle project's configurations if you need to setup a new project with jenkins!

I would like to end off this section with a fun fact: Some of the other companies that use this are 4linux, Cloudera, Dell, eBay, Facebook, GitHub, linkedIn, Netflix, yahoo, tumblr, and many more! 

### Step by step Tutorial

There are two ways you can use the test framework. 

#### Manually launching the test framework
One way is to manually launching the bindle_test_framework script whenever you made a change to your local repository and want to test that chaange without having to monitor the console output. For example, you might want to run the test framework overnight but on your local repository and not the remote repository. Since jenkins only takes care of remote repository(and that too, only for develop branch, release branch, and pull requests), you will want to execute this framework on your machine itself. I have  created a detailed step-by-step tutorial for this option which is located [here](https://github.com/CloudBindle/Bindle/edit/feature/bindle_test_framework/tester/test_framework_manual_launch.md)

#### Integrating the test framework with jenkins
I have already set up the test framework with jenkins for the develop branch, release branch, and for pull requests. However, in the near future, if you want to include any other branches to jenkins or need to modify the configuration currently set up for bindle, I have created a detailed tutorial on this as well which is located [here](https://github.com/CloudBindle/Bindle/edit/feature/bindle_test_framework/tester/test_framework_jenkins.md)

### Bindle Tester Dependencies

The tester/bin/bindle_test_framework.pl script requires Perl (of course) and also a few modules. They should already be installed if you are using a jenkins node but if not, you can install these using CPAN or via your distribution's package management system. Google "cpan perl install" for more information if you're unfamiliar with installing Perl packages. I highly recommend using PerlBrew to simplify working with Perl dependencies if you do not use your native package manager as shown below for Ubuntu:
* Net::OpenSSH
* HTML::Manipulator
* FileHandle
* File::Spec
It also uses other perl modules but those should already exist on your machine since they are needed for bindle. Please refer to bindle's readme if you don't have the other perl modules installed.

To check to see if you have these, you can do:

    perl -c tester/bin/bindle_test_framework.pl
	  
It should exit without an error message. 

### Configuration Files

Since the test framework launches clusters on multiple encironments, there are multiple configuration templates located at tester/config_templates. NOTE: Do not modify these templates! These are just there for the purposes of updating configuration templates in the future. If it is your first time executing the test_framework script, it will create a copy of all the templates in tester/config_templates at ~/.bindle/test_framework_configs/:

    perl tester/bin/bindle_test_framework.pl

Now, you can modify these as many times as you want because they are on your local machine. The reason why we do this is because these files contain sensitive information like passwords which we don't accidently want to commit on github and make it public. You can fill in the required information in all the configuration files:

    # fill in the information for both the cloud environments 
    # there will be a config for vcloud once the test framework supports that as well
    vim ~/.bindle/test_framework_configs/aws.cfg
    vim ~/.bindle/test_framework_configs/openstack-toronto-new.cfg
    
To get more information on filling in the configuration file, please refer to the bindle readme's "Filling the config file" section. However, I will go through the test framework specific parameters here.

    # seqware version and bwa workflow version should be the same version as 
    # the versions used by Bindle (currently its 1.0.15 and 2.6.0, respectively)
    seqware_version = 1.0.15
    bwa_workflow_version = 2.6.0
    # number of clusters should match the number of cluster blocks 
    # where the json_template_file_path is pointing to a "cluster" profile and not a "node" profile
    number_of_clusters = 1
    # number of single node clusters should match the number of single node blocks 
    # where the json_template_file_path is pointing to a "node" profile and not a "singlenode" profile    
    number_of_single_node_clusters = 1

Another thing to keep in mind while setting up configuration is to always name your cluster blocks by appending a number starting from 1 to "cluster" and "singlenode". For example, If you want to launch 4 clusters(2 multi-node and 2 single-node) in a cloud environment, then your cluster blocks should have the following headings:
    [cluster1],
    [cluster2],
    [singlenode1], and
    [singlenode2]

### Running Bindle Tester
Once everything has been configured properly, we are ready to execute the following command:

    # launch the test framework
    perl tester/bin/bindle_test_framework.pl --use-config-paths ~/.bindle/test_framework_configs/aws.cfg,~/.bindle/test_framework_configs/openstack-toronto-new.cfg --destroy-clusters
    
The "--use-config-paths" parameter is required and we need to specify the paths of all the config templates we want to launch (ex. if you only want to launch aws, then only include "~/.bindle/test_framework_configs/aws.cfg"). The list you can include is comma delimmited. The "--destroy-clusters" parameter simply destroys all the clusters that were launched and tested using this tool.  

### Adding Tests 
This section describes how to add more tests to the test framework. For this, you can navigate to tester/lib/ from the Bindle directory. Next, you can edit tests/pm.

		vim tests.pm
		
Within this file, you have two main methods which are "test_cluster_as_ubuntu" and "test_single_nodes_as_ubuntu". The first one is strictly to test multi-node clusters while the second one is to test a single-node cluster. Also, you already have the ssh object which will ssh into the master node of the cluster. So, all you need to do is create a sub routine where you execute a specific test and return a text output back which contains the test result (either a pass or fail). 

An example subroutine I will display here is "check_seqware_sanity" which is there to make sure that seqware is functioning properly by running the seqware sanity check tool:

	sub check_seqware_sanity{
    my ($ssh,$working_dir) = @_;
    my $findings = "";

    # get the seqware sanity check tool
    my $sanity_tool = $ssh->capture("sudo su - seqware -c 'cd jars;wget -q https://seqwaremaven.oicr.on.ca/artifactory/seqware-release/com/github/seqware/seqware-sanity-check/1.0.15/seqware-sanity-check-1.0.15-jar-with-dependencies.jar'");
    $ssh->error and return "FAIL: Unable to get the seqware sanity check tool: ".$ssh->error;
    system("echo '$sanity_tool' >> $working_dir/cluster.log");

    if ($ssh->test("sudo su - seqware -c 'java -jar jars/seqware-sanity-check-1.0.15-jar-with-dependencies.jar'")){
        $findings .= "PASS: Seqware sanity check tool ran successfully!\n";
    }
    else{
        $findings .= "FAIL: Seqware Sanity check tool was unsuccessful!\n";
    }
    $ssh->error and return "FAIL: Unable to run the seqware sanity check tool: ".$ssh->error;
    say "Tested seqware sanity check for $working_dir. The results are: \n\t$findings";

    return $findings;

	}

As you can see, a command can be executed on the remote machines by invoking $ssh->cpature("<cmd>") and this will capture the output to the variable. Another way to execute a command is by invoking $ssh->system("<cmd>"). However, this one doesn't store the output in a variale; it simply outputs it to the console. For more information on how to execute particular commands through ssh, please refer to Net::OpenSSH's documentation [here](http://search.cpan.org/~salva/Net-OpenSSH-0.62/lib/Net/OpenSSH.pm).

To add it to the two main methods, all we need to do is add the following line to the methods:

	# run the seqware sanity check tool to see if seqware is working properly
    $result .= check_seqware_sanity($ssh,$working_dir);

Now, you should be able to see the output of the test you added in results.html once you execute the test framework provided that there are no errors in your newly created test method.

### Adding Cloud Environments
The cloud environments can be distinguished in to two different sections. One is when you need to get access to a cluster equivalent to chickenwire and from there, you can launch clusters through Bindle. Other one is when you can launch clusters through Bindle from any launcher host. One example of the first one is vCloud. Examples of the second type are AWS and openstack at OICR which we currently have integrated with the test framework. 

In future, if you are given the task to include vCloud in this framework, it will be difficult since you will need to figure out how to login to a cluster similar to chickenwire, then launch a lucher host on that cluster. After that, you will have to launch and provision clusters on that launcher host via Bindle. Finally, you can test the cluster that were provisioned by Bindle and pass back the test results. As you can imagine, this is a tough task and due to time constraints, I wasn't able to get to it. However, there is a resource available to create a launcher host on a cloud environment. It is located in the "nexus" folder. This was designed by Adam and is primarily meant to create a launcher host on a cloud environment. From there, you can go onto launching,provisioning, and testing the clusters through Bindle Tester. 

It would be much simpler to integrate a cloud environment where you can launch clusters from any launcher host. For this, all you need to do is create a new configuration file under tester/config_templates. This configuration file should have all the required information to get access to and launch clusters on it. You can take a look at existing configuration files to look at what kind of parameters are needed. Once you have done that, you can mention the config path of the file in "--use-config-paths" argument while executing the Bindle Tester:

	 perl tester/bin/bindle_test_framework.pl --use-config-paths ~/.bindle/test_framework_configs/aws.cfg,~/.bindle/test_framework_configs/openstack-toronto-new.cfg --destroy-clusters
	 
If your configuration file is set up properly, the bindle tester should be functioning with the new cloud environment as well. 

### Commit ids from the latest build that was successful
* Seqware-bag: 00d4ae6eb8333616ca1cdad26f27a57c5babde90
* Bindle: fca12b40e7e500cec4ea6d1b8f0fb115358131a6
* Pancancer-bag: b0c9fbe949fc3c2a8ed1e2269a900f852a186ab9
* Seqware version: 1.0.15
* BWA version: 2.6.0
* Vagrant version used for Bindle: 1.6.3
* vagrant-aws version: 0.5.0
* vagrant-openstack-plugin version: 0.7.0

### TODOs
* Configure jenkins so that it doesn't build the test framework if the documentation is the only thing that has been changed and pushed to github. In other words, jenkins should build the test framework when there is "actual" code change.
* Add vCloud to the test framework (need to figure out how to login to EBI's equivalent of chickenwire)
* Distinguish between heavy test and light test. For now, all the tests are heavy but we would probably want to re-examine something like running a bwa workflow which takes 30 minutes in the future when vCloud also gets integrated into the framework.
* Need to make the multi-threading process more dynamic - currently, it is concurrent for launching multiple clusters within an environment, but the environments themselves are ran sequentially. Instead of this, we can make it parallel if we expand to other cloud environments such as vCloud.
