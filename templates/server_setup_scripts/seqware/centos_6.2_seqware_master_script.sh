#!/bin/bash -vx

# add seqware user
#useradd -d /home/seqware -m seqware -s /bin/bash

# create various seqware dirs
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

# setup jar
cp /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar /home/seqware/jars/

# setup seqware cli
cp /home/seqware/gitroot/seqware/seqware-pipeline/target/seqware /home/seqware/bin
chmod +x /home/seqware/bin/seqware
echo 'export PATH=$PATH:/home/seqware/bin' >> /home/seqware/.bash_profile

# make everything owned by seqware, readable by all
chown -R seqware:seqware /home/seqware
chmod -R a+rx /home/seqware

# seqware database
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

# stop tomcat6
/etc/init.d/tomcat6 stop

# remove landing page for tomcat
rm -rf /var/lib/tomcat6/webapps/ROOT

# seqware web service
cp /home/seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.war /var/lib/tomcat6/webapps/SeqWareWebService.war
cp /home/seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.xml /etc/tomcat6/Catalina/localhost/SeqWareWebService.xml
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /etc/tomcat6/Catalina/localhost/SeqWareWebService.xml

# seqware portal
cp /home/seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.war /var/lib/tomcat6/webapps/SeqWarePortal.war
cp /home/seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.xml /etc/tomcat6/Catalina/localhost/SeqWarePortal.xml
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /etc/tomcat6/Catalina/localhost/SeqWarePortal.xml

# restart tomcat6
/etc/init.d/tomcat6 start

# seqware landing page
cp -r /home/seqware/gitroot/seqware/seqware-distribution/docs/vm_landing/* /var/www/

# for glassfish database location during tests
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /home/seqware/gitroot/seqware/pom.xml

# run full integration testing
su - seqware -c 'cd /home/seqware/gitroot/seqware; %{SEQWARE_IT_CMD} 2>&1 | tee it.log'

# setup cronjobs after testing to avoid WorkflowStatusChecker or Launcher clashes
cp /vagrant/status.cron /home/seqware/crons/
chown -R seqware:seqware /home/seqware/crons
chmod a+x /home/seqware/crons/status.cron
su - seqware -c '(echo "* * * * * /home/seqware/crons/status.cron >> /home/seqware/logs/status.log") | crontab -'

# enable SELinux
echo 1 > /selinux/enforce