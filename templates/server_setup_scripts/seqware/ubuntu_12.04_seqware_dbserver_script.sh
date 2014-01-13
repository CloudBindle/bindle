#!/bin/bash -vx

# checkout seqware
cd /tmp
git clone https://github.com/SeqWare/seqware.git

export SEQWARE_VERSION=`ls /tmp/seqware/seqware-distribution/target/seqware-distribution-*-full.jar | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?' | head -1`

# seqware database
/etc/init.d/postgresql start
sudo -u postgres psql -c "CREATE USER seqware WITH PASSWORD 'seqware' CREATEDB;"
sudo -u postgres psql --command "ALTER USER seqware WITH superuser;"
# expose sql scripts
cp /tmp/seqware/seqware-meta-db/seqware_meta_db.sql /tmp/seqware_meta_db.sql
cp /tmp/seqware/seqware-meta-db/seqware_meta_db_data.sql /tmp/seqware_meta_db_data.sql
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
