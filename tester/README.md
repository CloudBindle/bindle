## Table of Contents

* [About Bindle Tester](#about-bindle-tester)

### About Bindle Tester

This project is a test framework for Bindle which is designed to test it whenever changes are made to the develop branch, release branch, or when a pull request has been made. This lets you build, provision, and test Linux virtual machines from scratch on various cloud environements (currently AWS and OICR Openstack). For more information on exactly how the build and provision process varies from doing it from vagrant directly, please refer to the Bindle README. 

This framework has been primarily constructed to follow the continous integration process and detect bugs right away once code has been pushed to this repository. This significantly reduces the amount of manual testing that need to be done to verify that bindle is provisioning the clusters correctly. How does this tool get the above job done? In short, the tool launches multiple clusters (currently single-node and two-node clusters but it can be scaled to more if required) on multiple cloud environments through bindle and then, it carries out a set of tests tailored toward each of the clusters. Based on the results, we can confirm whether or not the clusters were provisioned correctly. 

You can manually execute this project by executing the perl script under the bin folder of this directory. More on this later. However, the project has been integrated with jenkins which has the capability to automatically detect when someone makes changes to the Bindle repository. The bindle jenkins node contains all the configuration information of the different environments which need to be updated if required in order for the automated testing process of Bindle to work. This will be discussed in detail later. 

In the latest version of the script, we support automated testing on AWS and OICR openstack environments. In the near future, we will be looking into adding vCloud to the test framework as well. There will be a section which will discuss the pseudo process of how you can add a new cloud environment to this tool. The main goal of this project is minimize the long and tedious process of manual testing since provisioning a cluster itself takes about 30 minutes and testing it takes another 30 minutes. 
