#!/bin/bash -vx

# TODO:
# - need to create and install a HelloWorld workflow (optionally?) so SWID 1 is taken and the tutorials can be followed
# - what about seqware/root password for VirtualBox?

# add seqware user
mkdir -p /mnt/home
useradd -d /mnt/home/seqware -m seqware -s /bin/bash
ln -s /mnt/home/seqware /home/seqware

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

# I'm still checking out since I will need the SQL schema file for example
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

## build with develop
#su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_BRANCH_CMD}'
#su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_BUILD_CMD} 2>&1 | tee build.log'

# download various SeqWare components
export SEQWARE_VERSION="%{SEQWARE_VERSION}"
# since we're not building, go ahead and setup these dirs as the place to download jars
mkdir -p /home/seqware/gitroot/seqware/seqware-distribution/target/
mkdir -p /home/seqware/gitroot/seqware/seqware-webservice/target/
mkdir -p /home/seqware/gitroot/seqware/seqware-portal/target/
mkdir -p /home/seqware/gitroot/seqware/seqware-pipeline/target/
# download the released versions
curl -L http://seqwaremaven.oicr.on.ca/artifactory/seqware-release/com/github/seqware/seqware-distribution/${SEQWARE_VERSION}/seqware-distribution-${SEQWARE_VERSION}-full.jar > /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar
curl -L http://seqwaremaven.oicr.on.ca/artifactory/seqware-release/com/github/seqware/seqware-portal/${SEQWARE_VERSION}/seqware-portal-${SEQWARE_VERSION}.war >  /home/seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.war
curl -L http://seqwaremaven.oicr.on.ca/artifactory/seqware-release/com/github/seqware/seqware-webservice/${SEQWARE_VERSION}/seqware-webservice-${SEQWARE_VERSION}.war > /home/seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.war 
curl -L https://github.com/SeqWare/seqware/releases/download/${SEQWARE_VERSION}/seqware > /home/seqware/gitroot/seqware/seqware-pipeline/target/seqware
mkdir -p /home/seqware/.m2/
curl -L https://github.com/SeqWare/seqware/releases/download/${SEQWARE_VERSION}/archetype-catalog.xml > /home/seqware/.m2/archetype-catalog.xml
# copy the templates to their correct destination
cp /vagrant/seqware-webservice.xml /home/seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.xml
cp /vagrant/seqware-portal.xml /home/seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.xml

#export SEQWARE_VERSION=`ls /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-*-full.jar | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?' | head -1`

# setup jar
cp /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar /home/seqware/jars/

# setup seqware cli
cp /home/seqware/gitroot/seqware/seqware-pipeline/target/seqware /home/seqware/bin
chmod +x /home/seqware/bin/seqware
echo 'export PATH=$PATH:/home/seqware/bin' >> /home/seqware/.bash_profile

# make everything owned by seqware
chown -R seqware:seqware /home/seqware

# seqware database
/etc/init.d/postgresql start
sudo -u postgres psql -c "CREATE USER seqware WITH PASSWORD 'seqware' CREATEDB;"
sudo -u postgres psql --command "ALTER USER seqware WITH superuser;"
# expose sql scripts
cp /home/seqware/gitroot/seqware/seqware-meta-db/seqware_meta_db.sql /tmp/seqware_meta_db.sql
cp /home/seqware/gitroot/seqware/seqware-meta-db/seqware_meta_db_data.sql /tmp/seqware_meta_db_data.sql
chmod a+rx /tmp/seqware_meta_db.sql
chmod a+rx /tmp/seqware_meta_db_data.sql
# this is the DB actually used by people
sudo -u postgres psql --command "CREATE DATABASE seqware_meta_db WITH OWNER = seqware;"
sudo -u postgres psql seqware_meta_db < /tmp/seqware_meta_db.sql
sudo -u postgres psql seqware_meta_db < /tmp/seqware_meta_db_data.sql
# the testing DB
sudo -u postgres psql --command "CREATE DATABASE test_seqware_meta_db WITH OWNER = seqware;"
sudo -u postgres psql test_seqware_meta_db < /tmp/seqware_meta_db.sql
sudo -u postgres psql test_seqware_meta_db < /tmp/seqware_meta_db_data.sql

# stop tomcat7
/etc/init.d/tomcat7 stop

# remove landing page for tomcat
rm -rf /var/lib/tomcat7/webapps/ROOT

# seqware web service
cp /home/seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.war /var/lib/tomcat7/webapps/SeqWareWebService.war
cp /home/seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.xml /etc/tomcat7/Catalina/localhost/SeqWareWebService.xml
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /etc/tomcat7/Catalina/localhost/SeqWareWebService.xml

# seqware portal
cp /home/seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.war /var/lib/tomcat7/webapps/SeqWarePortal.war
cp /home/seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.xml /etc/tomcat7/Catalina/localhost/SeqWarePortal.xml
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /etc/tomcat7/Catalina/localhost/SeqWarePortal.xml

# restart tomcat7
/etc/init.d/tomcat7 start

# seqware landing page
cp -r /home/seqware/gitroot/seqware/seqware-distribution/docs/vm_landing/* /var/www/

## for glassfish database location during tests
#perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /home/seqware/gitroot/seqware/pom.xml 
## run full integration testing
#su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_IT_CMD} 2>&1 | tee it.log'

# setup cronjobs after testing to avoid WorkflowStatusChecker or Launcher clashes
cp /vagrant/status.cron /home/seqware/crons/
chown -R seqware:seqware /home/seqware/crons
chmod a+x /home/seqware/crons/status.cron
su - seqware -c '(echo "* * * * * /home/seqware/crons/status.cron >> /home/seqware/logs/status.log") | crontab -'

