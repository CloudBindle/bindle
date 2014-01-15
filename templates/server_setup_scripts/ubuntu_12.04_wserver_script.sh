#!/bin/bash -vx

# general apt-get
apt-get update
export DEBIAN_FRONTEND=noninteractive

# common installs for master and workers
apt-get -q -y --force-yes install git maven sysv-rc-conf xfsprogs

# the repos have been setup in the minimal script
apt-get -q -y --force-yes install tomcat6-common tomcat6 apache2

# setup daemons to start on boot
sysv-rc-conf tomcat6 on
