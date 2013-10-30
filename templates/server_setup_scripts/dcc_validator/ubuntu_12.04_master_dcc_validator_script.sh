#!/bin/bash -vx

# setup apt
export DEBIAN_FRONTEND=noninteractive

# prepare a location for the DCC validator
mkdir -p /mnt/dcc-portal
cd /mnt/dcc-portal

# setup Mongo
# get key
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
# get the aptget settings
echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | tee /etc/apt/sources.list.d/mongodb.list
apt-get update
apt-get -q -y --force-yes install mongodb-10gen=2.4.1
service mongodb restart
# sleep for 5 minutes to ensure Mongo comes online
sleep 5m

# now get the DCC app
wget http://seqwaremaven.oicr.on.ca/artifactory/dcc-release/org/icgc/dcc/dcc-submission-server/2.0.1/dcc-submission-server-2.0.1-dist.tar.gz
tar zxf dcc-submission-server-2.0.1-dist.tar.gz

# copy the correct config that has been customized for DCC
cp /vagrant/application.conf /mnt/dcc-portal/dcc-submission-server-2.0.1/conf/
cp /vagrant/init.sh /mnt/dcc-portal/dcc-submission-server-2.0.1/

# start the process
/bin/sh /mnt/dcc-portal/dcc-submission-server-2.0.1/bin/dcc-submission-server install
service dcc-submission-server start

# run the init process
bash /mnt/dcc-portal/dcc-submission-server-2.0.1/init.sh http://%{DCC_VALIDATOR_DICTIONARY_SERVER}:%{DCC_VALIDATOR_DICTIONARY_PORT} http://localhost:5380 %{DCC_VALIDATOR_USER} %{DCC_VALIDATOR_PASSWD} Release1 project1 Project1 Project1

