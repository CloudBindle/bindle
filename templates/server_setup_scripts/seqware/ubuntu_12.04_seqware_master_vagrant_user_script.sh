#!/bin/bash -vx

# ABOUT:
# This script sets up the vagrant user so it can be used to develop 
# workflows via VirtualBox. This user is not useful in the context 
# of cloud installs since there is no shared filesystem between the
# users local computer and the remote cloud instance.

# various seqware dirs
mkdir -p ~vagrant/bin
mkdir -p ~vagrant/jars
mkdir -p ~vagrant/crons
mkdir -p ~vagrant/logs
mkdir -p ~vagrant/released-bundles
mkdir -p ~vagrant/provisioned-bundles
mkdir -p ~vagrant/workflow-dev
mkdir -p ~vagrant/.seqware
mkdir -p ~vagrant/gitroot/seqware
sudo -u hdfs hadoop fs -mkdir -p /user/vagrant
sudo -u hdfs hadoop fs -chown -R vagrant /user/vagrant

# configure seqware settings
cp /vagrant/settings ~vagrant/.seqware/
perl -p -i -e 's/\/home\/seqware\//\/home\/vagrant\//g' .seqware/settings
perl -p -i -e 's/\/user\/seqware\//\/user\/vagrant\//g' .seqware/settings

# install hubflow
cd ~vagrant/gitroot
git clone https://github.com/datasift/gitflow
cd gitflow
./install.sh

# setup bash_profile for seqware
echo "export MAVEN_OPTS='-Xmx1024m -XX:MaxPermSize=512m'" >> ~vagrant/.bash_profile

# make everything owned by seqware
chown -R vagrant:vagrant ~vagrant

# correct permissions
su - vagrant -c 'chmod 640 ~vagrant/.seqware/settings'

# download various SeqWare components
export SEQWARE_VERSION="%{SEQWARE_VERSION}"
# since we're not building, go ahead and setup these dirs as the place to download jars
mkdir -p ~vagrant/gitroot/seqware/seqware-distribution/target/
mkdir -p ~vagrant/gitroot/seqware/seqware-webservice/target/
mkdir -p ~vagrant/gitroot/seqware/seqware-portal/target/
mkdir -p ~vagrant/gitroot/seqware/seqware-pipeline/target/
# download the released versions
curl -L http://seqwaremaven.oicr.on.ca/artifactory/seqware-release/com/github/seqware/seqware-distribution/${SEQWARE_VERSION}/seqware-distribution-${SEQWARE_VERSION}-full.jar > ~vagrant/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar
curl -L https://github.com/SeqWare/seqware/releases/download/${SEQWARE_VERSION}/seqware > ~vagrant/gitroot/seqware/seqware-pipeline/target/seqware
mkdir -p ~vagrant/.m2/
curl -L https://github.com/SeqWare/seqware/releases/download/${SEQWARE_VERSION}/archetype-catalog.xml > ~vagrant/.m2/archetype-catalog.xml

# setup jar
cp ~vagrant/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar /jars/

# setup seqware cli
cp ~vagrant/gitroot/seqware/seqware-pipeline/target/seqware /bin
chmod +x ~vagrant/bin/seqware
echo 'export PATH=$PATH:~vagrant/bin' >> ~vagrant/.bash_profile

# make everything owned by seqware
chown -R vagrant:vagrant ~vagrant

## setup cronjobs after testing to avoid WorkflowStatusChecker or Launcher clashes
#cp /vagrant/status.cron ~vagrant/crons/
#chown -R seqware:seqware ~vagrant/crons
#chmod a+x ~vagrant/crons/status.cron
#su - seqware -c '(echo "* * * * * ~vagrant/crons/status.cron >> /logs/status.log") | crontab -'

#cd ~vagrant
#wget https://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_HelloWorld_1.0-SNAPSHOT_SeqWare_1.0.11.zip
#su - seqware -c 'seqware bundle install --zip Workflow_Bundle_HelloWorld*'

