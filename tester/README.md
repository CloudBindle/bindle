## Table of Contents

* [About Bindle Tester](#about-bindle-tester)
* [Step by step Tutorial](#step-by-step-tutorial)
  * [Manually launching the test framework](#manually-launching-the-test-framework)
  * [Integrating the test framework with jenkins](#integrating-the-test-framework-with-jenkins)
* [Bindle Tester Dependencies](#installing)
* [TODOs](#todos)

### About Bindle Tester

This project is a test framework for Bindle which is designed to test it whenever changes are made to the develop branch, release branch, or when a pull request has been made. This lets you build, provision, and test Linux virtual machines from scratch on various cloud environements (currently AWS and OICR Openstack). For more information on exactly how the build and provision process varies from doing it from vagrant directly, please refer to the Bindle README. 

This framework has been primarily constructed to follow the continous integration process and detect bugs right away once code has been pushed to this repository. This significantly reduces the amount of manual testing that need to be done to verify that bindle is provisioning the clusters correctly. How does this tool get the above job done? In short, the tool launches multiple clusters (currently single-node and two-node clusters but it can be scaled to more if required) on multiple cloud environments through bindle and then, it carries out a set of tests tailored toward each of the clusters. Based on the results, we can confirm whether or not the clusters were provisioned correctly. 

You can manually execute this project by executing the perl script under the bin folder of this directory. More on this later. However, the project has been integrated with jenkins which has the capability to automatically detect when someone makes changes to the Bindle repository. The bindle jenkins node contains all the configuration information of the different environments which need to be updated if required in order for the automated testing process of Bindle to work. This will be discussed in detail later. 

In the latest version of the script, we support automated testing on AWS and OICR openstack environments. In the near future, we will be looking into adding vCloud to the test framework as well. There will be a section which will discuss the pseudo process of how you can add a new cloud environment to this tool. The main goal of this project is minimize the long and tedious process of manual testing since provisioning a cluster itself takes about 30 minutes and testing it takes another 30 minutes. 

### What is Jenkins?
You might be wondering what Jenkins is all about because I certianly did when I first got introduced to it. For our purposes, it is an open source continous integration tool that is able to detect if there are any code changes to the repository on github and if so, then it has the ability to monitor a build system. This is the perfect way to catch errors quickly and locate them more easily. Jenkins can also provide reports and notifications to alert developers on success or on errors. So, we utilitze jenkins just for this purpose; we use the test framework as the "build" and generate a html report at the end of the build which contains the test results! Some tips/tutorial I found helpful while working with jenkins:
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

### TODOs
* Configure jenkins so that it doesn't build the test framework if the documentation is the only thing that has been changed and pushed to github. In other words, jenkins should build the test framework when there is "actual" code change.
* Add vCloud to the test framework (need to figure out how to login to EBI's equivalent of chickenwire)
* Distinguish between heavy test and light test. For now, all the tests are heavy but we would probably want to re-examine something like running a bwa workflow which takes 30 minutes in the future when vCloud also gets integrated into the framework.
* Need to make the multi-threading process more dynamic - currently, it is concurrent for launching multiple clusters within an environment, but the environments themselves are ran sequentially. Instead of this, we can make it parallel if we expand to other cloud environments such as vCloud.
