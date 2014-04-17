capsid-vagrant
==============

Vagrant and associated deployment framework for CaPSID

The easiest way to use this is as follows:

```shell
$ vagrant up
```

This will start up a set of virtual machines for a small CaPSID cluster. 
At this stage, nothing yet has been provisioned, so nothing at all will
work. To provision, use:

```shell
$ ./deploy.sh
```

This currently works only with Virtualbox. 
