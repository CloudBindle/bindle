#!/bin/bash -vx

export SEQWARE_VERSION=`ls /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-*-full.jar | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?' | head -1`

# setup jar
cp /home/seqware/gitroot/seqware/seqware-distribution/target/seqware-distribution-${SEQWARE_VERSION}-full.jar /home/seqware/jars/

# setup seqware cli
cp /home/seqware/gitroot/seqware/seqware-pipeline/target/seqware /home/seqware/bin
chmod +x /home/seqware/bin/seqware
echo 'export PATH=$PATH:/home/seqware/bin' >> /home/seqware/.bash_profile

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

