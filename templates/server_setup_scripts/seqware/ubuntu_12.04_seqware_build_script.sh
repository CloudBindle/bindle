#!/bin/bash -vx

# Build seqware from source code

# add seqware user
useradd -d /home/seqware -m seqware -s /bin/bash

# various seqware dirs
mkdir -p /home/seqware/bin
mkdir -p /home/seqware/jars
mkdir -p /home/seqware/crons
mkdir -p /home/seqware/logs
mkdir -p /home/seqware/released-bundles
mkdir -p /home/seqware/provisioned-bundles
mkdir -p /home/seqware/workflow-dev
mkdir -p /home/seqware/.seqware
mkdir -p /home/seqware/gitroot/seqware
sudo -u hdfs hadoop fs -mkdir -p /user/seqware
sudo -u hdfs hadoop fs -chown -R seqware /user/seqware

# configure seqware settings
cp /vagrant/settings /home/seqware/.seqware

# install hubflow
cd /home/seqware/gitroot
git clone https://github.com/datasift/gitflow
cd gitflow
./install.sh

# checkout seqware
cd /home/seqware/gitroot
git clone https://github.com/SeqWare/seqware.git

# setup bash_profile for seqware
echo "export MAVEN_OPTS='-Xmx1024m -XX:MaxPermSize=512m'" >> /home/seqware/.bash_profile

# make everything owned by seqware
chown -R seqware:seqware /home/seqware

# correct permissions
su - seqware -c 'chmod 640 /home/seqware/.seqware/settings'

# configure hubflow
su - seqware -c 'cd /home/seqware/gitroot/seqware; git hf init; git hf update'

# build with develop
su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_BRANCH_CMD}'
su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_BUILD_CMD} 2>&1 | tee build.log'

export SEQWARE_VERSION=`ls /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-*-full.jar | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?' | head -1`

# make everything owned by seqware
chown -R seqware:seqware /home/seqware
