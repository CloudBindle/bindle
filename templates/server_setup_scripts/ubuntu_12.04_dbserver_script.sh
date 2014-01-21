#!/bin/bash -vx

# Setup for postgres allowing remote access and setup with permissions for oozie
# This script should remain modular enough that it be run both on the master (if everything is self contained on one VM) or on a dedicated db server

# common installs for master and workers
apt-get -q -y --force-yes install git maven sysv-rc-conf xfsprogs
# the repos have been setup in the minimal script
apt-get -q -y --force-yes install postgresql-9.1 postgresql-client-9.1

sudo -u postgres psql --command "CREATE ROLE oozie LOGIN ENCRYPTED PASSWORD 'oozie' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
sudo -u postgres psql --command "CREATE DATABASE oozie WITH OWNER = oozie ENCODING = 'UTF-8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "host    oozie         oozie         0.0.0.0/0             md5" >> /etc/postgresql/9.1/main/pg_hba.conf
echo "host    all         all         samenet             trust" >> /etc/postgresql/9.1/main/pg_hba.conf
sudo perl -pi -e  "s/#listen_addresses = 'localhost'/listen_addresses = '*'/;" /etc/postgresql/9.1/main/postgresql.conf
sudo perl -pi -e  "s/local\h*all\h*all\h*peer/local all all trust/;" /etc/postgresql/9.1/main/pg_hba.conf
sudo -u postgres /usr/lib/postgresql/9.1/bin/pg_ctl reload -s -D /var/lib/postgresql/9.1/main
# the above did not seem to be enough
sudo service postgresql restart
