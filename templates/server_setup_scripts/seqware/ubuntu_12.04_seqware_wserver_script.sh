#!/bin/bash -vx

export SEQWARE_VERSION=`ls /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-*-full.jar | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?' | head -1`

# stop tomcat6
/etc/init.d/tomcat6 stop

# remove landing page for tomcat
rm -rf /var/lib/tomcat6/webapps/ROOT

# seqware web service
cp /home/seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.war /var/lib/tomcat6/webapps/SeqWareWebService.war
cp /home/seqware/gitroot/seqware/seqware-webservice/target/seqware-webservice-${SEQWARE_VERSION}.xml /etc/tomcat6/Catalina/localhost/SeqWareWebService.xml
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /etc/tomcat6/Catalina/localhost/SeqWareWebService.xml
perl -pi -e "s/localhost/%{SEQWARE_DB_SERVER}/;" /etc/tomcat6/Catalina/localhost/SeqWareWebService.xml

# seqware portal
cp /home/seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.war /var/lib/tomcat6/webapps/SeqWarePortal.war
cp /home/seqware/gitroot/seqware/seqware-portal/target/seqware-portal-${SEQWARE_VERSION}.xml /etc/tomcat6/Catalina/localhost/SeqWarePortal.xml
perl -pi -e "s/test_seqware_meta_db/seqware_meta_db/;" /etc/tomcat6/Catalina/localhost/SeqWarePortal.xml
perl -pi -e "s/localhost/%{SEQWARE_DB_SERVER}/;" /etc/tomcat6/Catalina/localhost/SeqWarePortal.xml

# restart tomcat6
/etc/init.d/tomcat6 start

