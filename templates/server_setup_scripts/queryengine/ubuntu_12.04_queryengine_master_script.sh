#!/bin/bash -vx

# add seqware user
mkdir -p /mnt/home
useradd -d /mnt/home/seqware -m seqware -s /bin/bash
ln -s /mnt/home/seqware ~seqware

# various seqware dirs
mkdir -p ~seqware/bin
mkdir -p ~seqware/jars
mkdir -p ~seqware/logs
mkdir -p ~seqware/.seqware
mkdir -p ~seqware/gitroot/seqware
sudo -u hdfs hadoop fs -mkdir -p /user/seqware
sudo -u hdfs hadoop fs -chown -R seqware /user/seqware

# configure seqware settings
cp /vagrant/settings ~seqware/.seqware

# install hubflow
cd ~seqware/gitroot
git clone https://github.com/datasift/gitflow
cd gitflow
./install.sh

# checkout seqware
cd ~seqware/gitroot
git clone https://github.com/SeqWare/queryengine.git seqware

# setup bash_profile for seqware
echo "export MAVEN_OPTS='-Xmx1024m -XX:MaxPermSize=512m'" >> ~seqware/.bash_profile

# make everything owned by seqware
chown -R seqware:seqware ~seqware

# correct permissions
su - seqware -c 'chmod 600 ~seqware/.seqware/*'

# configure hubflow
su - seqware -c 'cd ~seqware/gitroot/seqware; git hf init; git hf update'

# build with develop
su - seqware -c 'cd ~seqware/gitroot/seqware; %{SEQWARE_BRANCH_CMD}'
su - seqware -c 'cd ~seqware/gitroot/seqware; %{SEQWARE_BUILD_CMD} 2>&1 | tee build.log'

export SEQWARE_VERSION=`ls ~seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-*-full.jar | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?' | head -1`

# setup jar
cp ~seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar ~seqware/jars/

# make everything owned by seqware
chown -R seqware:seqware ~seqware

# stop tomcat7
/etc/init.d/tomcat7 stop

# remove landing page for tomcat
rm -rf /var/lib/tomcat7/webapps/ROOT

# restart tomcat7
/etc/init.d/tomcat7 start

# seqware landing page
cp -r ~seqware/gitroot/seqware/seqware-distribution/docs/vm_landing/* /var/www/

# seqware tutorials
# required for running oozie jobs
mkdir /usr/lib/hadoop-0.20-mapreduce/.seqware
mkdir /var/lib/hadoop-mapreduce/.seqware
cp ~seqware/.seqware/settings /usr/lib/hadoop-0.20-mapreduce/.seqware/settings
cp ~seqware/.seqware/settings /var/lib/hadoop-mapreduce/.seqware/settings
chown -R mapred:mapred /usr/lib/hadoop-0.20-mapreduce/.seqware
chown -R mapred:mapred /var/lib/hadoop-mapreduce/.seqware

# run full integration testing
su - seqware -c 'cd ~seqware/gitroot/seqware; %{SEQWARE_IT_CMD} 2>&1 | tee it.log'

