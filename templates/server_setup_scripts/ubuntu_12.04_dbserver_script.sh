#!/bin/bash -vx

# first, fix the /etc/hosts file since SGE wants reverse lookup to work
cp /etc/hosts /tmp/hosts
echo `/sbin/ifconfig  | grep -A 3 eth0 | grep 'inet addr' | perl -e 'while(<>){ chomp; /inet addr:(\d+\.\d+\.\d+\.\d+)/; print $1; }'` `hostname` > /etc/hosts
cat /tmp/hosts | grep -v '127.0.1.1' >> /etc/hosts

# setup hosts
# NOTE: the hostname seems to already be set at least on BioNimubs OS
echo '%{HOSTS}' >> /etc/hosts
hostname master

# the repos have been setup in the minimal script
apt-get -q -y --force-yes install postgresql-9.1 postgresql-client-9.1

sudo -u postgres psql --command "CREATE ROLE oozie LOGIN ENCRYPTED PASSWORD 'oozie' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
sudo -u postgres psql --command "CREATE DATABASE oozie WITH OWNER = oozie ENCODING = 'UTF-8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "host    oozie         oozie         0.0.0.0/0             md5" >> /etc/postgresql/9.1/main/pg_hba.conf
echo "host    all         all         samenet             trust" >> /etc/postgresql/9.1/main/pg_hba.conf
sudo perl -pi -e  "s/listen_addresses = 'localhost'/listen_addresses = '*'/;" /etc/postgresql/9.1/main/postgresql.conf
sudo -u postgres /usr/lib/postgresql/9.1/bin/pg_ctl reload -s -D /var/lib/postgresql/9.1/main
