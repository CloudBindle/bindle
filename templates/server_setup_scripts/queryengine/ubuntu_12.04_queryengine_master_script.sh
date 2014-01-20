#!/bin/bash -vx

# add seqware user
useradd -d /home/seqware -m seqware -s /bin/bash

# various seqware dirs
mkdir -p /home/seqware/bin
mkdir -p /home/seqware/jars
mkdir -p /home/seqware/logs
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
git clone https://github.com/SeqWare/queryengine.git seqware

# setup bash_profile for seqware
echo "export MAVEN_OPTS='-Xmx1024m -XX:MaxPermSize=512m'" >> /home/seqware/.bash_profile

# make everything owned by seqware
chown -R seqware:seqware /home/seqware

# correct permissions
su - seqware -c 'chmod 600 /home/seqware/.seqware/*'

# configure hubflow
su - seqware -c 'cd /home/seqware/gitroot/seqware; git hf init; git hf update'

# build with develop
su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_BRANCH_CMD}'
su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_BUILD_CMD} 2>&1 | tee build.log'

export SEQWARE_VERSION=`ls /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-*-full.jar | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?' | head -1`

# setup jar
cp /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar /home/seqware/jars/

# make everything owned by seqware
chown -R seqware:seqware /home/seqware

# stop tomcat6
/etc/init.d/tomcat6 stop

# remove landing page for tomcat
rm -rf /var/lib/tomcat6/webapps/ROOT

# restart tomcat6
/etc/init.d/tomcat6 start

# seqware landing page
cp -r /home/seqware/gitroot/seqware/seqware-distribution/docs/vm_landing/* /var/www/

# seqware tutorials
# required for running oozie jobs
mkdir /usr/lib/hadoop-0.20-mapreduce/.seqware
mkdir /var/lib/hadoop-mapreduce/.seqware
cp /home/seqware/.seqware/settings /usr/lib/hadoop-0.20-mapreduce/.seqware/settings
cp /home/seqware/.seqware/settings /var/lib/hadoop-mapreduce/.seqware/settings
chown -R mapred:mapred /usr/lib/hadoop-0.20-mapreduce/.seqware
chown -R mapred:mapred /var/lib/hadoop-mapreduce/.seqware

# run full integration testing
su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_IT_CMD} 2>&1 | tee it.log'

