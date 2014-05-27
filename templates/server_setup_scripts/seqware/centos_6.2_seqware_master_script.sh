#!/bin/bash -vx

# add seqware user
#useradd -d ~seqware -m seqware -s /bin/bash

# various seqware dirs
mkdir -p ~seqware/bin
mkdir -p ~seqware/jars
mkdir -p ~seqware/crons
mkdir -p ~seqware/logs
mkdir -p ~seqware/released-bundles
mkdir -p ~seqware/provisioned-bundles
mkdir -p ~seqware/workflow-dev
mkdir -p ~seqware/.seqware
mkdir -p ~seqware/gitroot/seqware
sudo -u hdfs hadoop fs -mkdir -p /user/seqware
sudo -u hdfs hadoop fs -chown -R seqware /user/seqware

# configure seqware settings
\cp /vagrant/settings ~seqware/.seqware

# install hubflow
cd ~seqware/gitroot
git clone https://github.com/datasift/gitflow
cd gitflow
./install.sh

# checkout seqware
cd ~seqware/gitroot
git clone https://github.com/SeqWare/seqware.git

# setup bash_profile for seqware
echo "export MAVEN_OPTS='-Xmx1024m -XX:MaxPermSize=512m'" >> ~seqware/.bash_profile

# make everything owned by seqware
chown -R seqware:seqware ~seqware
chmod -R a+rx ~seqware

# correct permissions
su - seqware -c 'chmod 640 ~seqware/.seqware/settings'

# configure hubflow
su - seqware -c 'cd ~seqware/gitroot/seqware; git hf init; git hf update'

# build with develop
su - seqware -c 'cd ~seqware/gitroot/seqware; %{SEQWARE_BRANCH_CMD}'
su - seqware -c 'cd ~seqware/gitroot/seqware; %{SEQWARE_BUILD_CMD} 2>&1 | tee build.log'

export SEQWARE_VERSION=`ls ~seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-*-full.jar | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?' | head -1`

# setup jar
\cp ~seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar ~seqware/jars/

# setup seqware cli
\cp ~seqware/gitroot/seqware/seqware-pipeline/target/seqware ~seqware/bin
chmod +x ~seqware/bin/seqware
echo 'export PATH=$PATH:~seqware/bin' >> ~seqware/.bash_profile

# make everything owned by seqware
chown -R seqware:seqware ~seqware

# seqware database
service postgresql-9.3 start
sudo -u postgres psql -c "CREATE USER seqware WITH PASSWORD 'seqware' CREATEDB;"
sudo -u postgres psql --command "ALTER USER seqware WITH superuser;"
# expose sql scripts
\cp ~seqware/gitroot/seqware/seqware-meta-db/seqware_meta_db.sql /tmp/seqware_meta_db.sql
\cp ~seqware/gitroot/seqware/seqware-meta-db/seqware_meta_db_data.sql /tmp/seqware_meta_db_data.sql
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
/etc/init.d/tomcat stop

# remove landing page for tomcat
\rm -rf  /opt/apache-tomcat-7.0.54/webapps/ROOT

# seqware web service
\cp ~seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.war /opt/apache-tomcat-7.0.54/SeqWareWebService.war
\cp ~seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.xml /opt/apache-tomcat-7.0.54/conf/Catalina/localhost/SeqWareWebService.xml
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /opt/apache-tomcat-7.0.54/conf/Catalina/localhost/SeqWareWebService.xml

# seqware portal
\cp ~seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.war /opt/apache-tomcat-7.0.54/webapps/SeqWarePortal.war
\cp ~seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.xml /opt/apache-tomcat-7.0.54/conf/Catalina/localhost/SeqWarePortal.xml
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /opt/apache-tomcat-7.0.54/conf/Catalina/localhost/SeqWarePortal.xml

# restart tomcat7
/etc/init.d/tomcat start

# seqware landing page
\cp -r ~seqware/gitroot/seqware/seqware-distribution/docs/vm_landing/* /var/www/

# for glassfish database location during tests
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" ~seqware/gitroot/seqware/pom.xml
# run full integration testing
su - seqware -c 'cd ~seqware/gitroot/seqware; %{SEQWARE_IT_CMD} 2>&1 | tee it.log'

# setup cronjobs after testing to avoid WorkflowStatusChecker or Launcher clashes
\cp /vagrant/status.cron ~seqware/crons/
chown -R seqware:seqware ~seqware/crons
chmod a+x ~seqware/crons/status.cron
su - seqware -c '(echo "* * * * * ~seqware/crons/status.cron >> ~seqware/logs/status.log") | crontab -'

# enable SELinux
echo 1 > /selinux/enforce