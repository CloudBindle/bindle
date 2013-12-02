#!/bin/bash -vx

# setup apt
export DEBIAN_FRONTEND=noninteractive

# prepare a location for the DCC validator
mkdir -p /mnt/dcc-portal/data
mkdir -p /mnt/dcc-portal/icgc
mkdir -p /mnt/dcc-portal/dcc_root_dir
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
sleep 3m

# now get the DCC app
##wget http://seqwaremaven.oicr.on.ca/artifactory/dcc-release/org/icgc/dcc/dcc-submission-server/2.1.0/dcc-submission-server-2.1.0-dist.tar.gz
##tar zxf dcc-submission-server-2.1.0-dist.tar.gz
wget http://seqwaremaven.oicr.on.ca/artifactory/dcc-release/org/icgc/dcc/dcc-submission-server/2.0.1/dcc-submission-server-2.0.1-dist.tar.gz
tar zxf dcc-submission-server-2.0.1-dist.tar.gz

# Patch max memory usage - overwrite either absolute or percentage attrs
sudo cp /mnt/dcc-portal/dcc-submission-server-2.0.1/conf/wrapper.conf /mnt/dcc-portal/dcc-submission-server-2.0.1/conf/wrapper.conf_orig
sudo sed 's/wrapper.java.maxmemory=.*$/wrapper.java.maxmemory.percent=80/g' wrapper.conf_orig > /mnt/dcc-portal/dcc-submission-server-2.0.1/conf/wrapper.conf

# copy the correct config that has been customized for DCC
##cp /vagrant/application.conf /mnt/dcc-portal/dcc-submission-server-2.1.0/conf/
##cp /vagrant/init.sh /mnt/dcc-portal/dcc-submission-server-2.1.0/
cp /vagrant/application.conf /mnt/dcc-portal/dcc-submission-server-2.0.1/conf/application.conf
cp /vagrant/realm.ini /mnt/dcc-portal/dcc-submission-server-2.0.1/conf/
cp /vagrant/init.sh /mnt/dcc-portal/dcc-submission-server-2.0.1/
cp /vagrant/error.html /mnt/dcc-portal/dcc-submission-server-2.0.1/

# get the reference genome
cd data
wget http://seqwaremaven.oicr.on.ca/artifactory/simple/dcc-dependencies/org/icgc/dcc/dcc-reference-genome/GRCh37/dcc-reference-genome-GRCh37.tar.gz
tar zxf dcc-reference-genome-GRCh37.tar.gz
rm dcc-reference-genome-GRCh37.tar.gz
cd ..

# start the process
# FIXME: are these redundant!?!?
##/mnt/dcc-portal/dcc-submission-server-2.1.0/bin/install -s
##/bin/sh /mnt/dcc-portal/dcc-submission-server-2.1.0/bin/dcc-submission-server install -s
#/mnt/dcc-portal/dcc-submission-server-2.0.1/bin/install -l
sudo /mnt/dcc-portal/dcc-submission-server-2.0.1/bin/install -l
sleep 10

# run the init process
# NOTE: make sure your password is single quoted if it contains characters like @ which are interpreted by Bash
##bash /mnt/dcc-portal/dcc-submission-server-2.1.0/init.sh http://%{DCC_VALIDATOR_DICTIONARY_SERVER}:%{DCC_VALIDATOR_DICTIONARY_PORT} http://localhost:5380 %{DCC_VALIDATOR_USER} %{DCC_VALIDATOR_PASSWD} Release1 project1 Project1 Project1
bash /mnt/dcc-portal/dcc-submission-server-2.0.1/init.sh http://%{DCC_VALIDATOR_DICTIONARY_SERVER}:%{DCC_VALIDATOR_DICTIONARY_PORT} http://localhost:5380 %{DCC_VALIDATOR_USER} %{DCC_VALIDATOR_PASSWD} Release1 project1 Project1 Project1

# now make sure the above will happen on reboot
echo "
/mnt/dcc-portal/dcc-submission-server-2.0.1/bin/install -l
sleep 10
bash /mnt/dcc-portal/dcc-submission-server-2.0.1/init.sh https://submissions.dcc.icgc.org http://localhost:5380 %{DCC_VALIDATOR_USER} %{DCC_VALIDATOR_PASSWD} Release1 project1 Project1 Project1
if [ "\"\$?\"" != 0 ]; then
   cp -v /mnt/dcc-portal/dcc-submission-server-2.0.1/error.html /mnt/dcc-portal/dcc-submission-server-2.0.1/www/public/index.html
fi
exit 0
" > /etc/rc.local






