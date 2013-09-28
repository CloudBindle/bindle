#!/bin/bash -vx

# setup hosts
# NOTE: the hostname seems to already be set at least on BioNimubs OS
echo '%{HOSTS}' >> /etc/hosts
hostname %{HOST}

# basic tools
export DEBIAN_FRONTEND=noninteractive
apt-get update

echo "elasticsearch - nofile  65535
elasticsearch - memlock unlimited
" > /etc/security/limits.d/elasticsearch.conf

# install elasticsearch
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.1.deb
dpkg --force-depends -i elasticsearch-0.90.1.deb

# setup java_home
echo 'JAVA_HOME=/usr/lib/jvm/j2sdk1.6-oracle' >> /etc/default/elasticsearch

# now restart so it picks up the java setting
/etc/init.d/elasticsearch restart

# for backup/restore
/usr/share/elasticsearch/bin/plugin -remove knapsack
/usr/share/elasticsearch/bin/plugin -url http://dl.bintray.com/jprante/elasticsearch-plugins/org/xbib/elasticsearch/plugin/elasticsearch-knapsack/2.0.0/elasticsearch-knapsack-2.0.0.zip?direct -install knapsack

# display
/usr/share/elasticsearch/bin/plugin -remove head
/usr/share/elasticsearch/bin/plugin -install mobz/elasticsearch-head

# FIXME: this script should not do this, instead the config file should be a template
perl -pi -e 's/\#ES_HEAP_SIZE=2g/ES_HEAP_SIZE=%{DCC_ES_HEAP_SIZE_GB}g/' /etc/init.d/elasticsearch
perl -pi -e 's/\# bootstrap.mlockall: true/bootstrap.mlockall: true/' /etc/elasticsearch/elasticsearch.yml
perl -pi -e 's/\# discovery.zen.minimum_master_nodes: 1/discovery.zen.minimum_master_nodes: %{DCC_ES_MIN_MASTER_NODES}/' /etc/elasticsearch/elasticsearch.yml
# setup local dirs for elasticsearch
# TODO: should setup other ephemeral disks with my perl script and stripe across them
mkdir -p /mnt/es/data
perl -pi -e 's/^\# path.data: \/path\/to\/data$/path.data: \/mnt\/es\/data/' /etc/elasticsearch/elasticsearch.yml
mkdir -p /mnt/es/work
perl -pi -e 's/\# path.work: \/path\/to\/work/path.work: \/mnt\/es\/work/' /etc/elasticsearch/elasticsearch.yml
# now setup the hosts
perl -pi -e 's/# discovery.zen.ping.unicast.hosts: ["host1", "host2:port", "host3[portX-portY]"]/discovery.zen.ping.unicast.hosts: [%{DCC_ES_HOSTS_STR}]/' /etc/elasticsearch/elasticsearch.yml
# now turnoff automatic discovery
perl -pi -e 's/\# discovery.zen.ping.multicast.enabled/discovery.zen.ping.multicast.enabled/' /etc/elasticsearch/elasticsearch.yml

# owned by ES
chown -R elasticsearch:elasticsearch /mnt/es

# now restart to pickup changes above
/etc/init.d/elasticsearch restart

