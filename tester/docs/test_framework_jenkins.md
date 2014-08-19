## Integrating Jenkins with Bindle Test Framework Tutorial

This is our SOP on how one can integrate the Bindle Tester with Jenkins. This approach establishes continous integration for Bindle which can be very useful while it is undergoing development. Continous Integration is a development practise that requires developers to integrate code into a shared repository several times a day. Each check-in is then verified by an automated build. Currently, we are examining code changes only for the develop and release branches and also watching out for pull requests. 

### Use Cases
One use case for integrating Jenkins with Bindle Tester is to detect problems earlier and locate them easily since we know what code changes has caused this problem. Another use case is that it significantly reduces the time taken to manually test bindle. 

###Summary of the steps

Please note that some of the steps described here can be skipped. For example, if you already have a functioning jenkins slave for bindle and simple want to create a new project or modify the configuration of a jenkins project, then you can skip the first step.

* Launch an instance from Openstack's web console and call it something like "bindle_jenkins_slave_1". Then, provision the slave node via seqware-sandbox
* Log into Jenkins console by writing "jenkins" in the address bar of a web browser and create a new project
* Click on the project and navigate to the "configure" screen
* Fill in the configuration and save it!
* Copy the config templates to ~/.bindle/test_framework_configs and fill all the required information there
* You are ready to test it by making code changes or pressing the build now button in jenkins console!
