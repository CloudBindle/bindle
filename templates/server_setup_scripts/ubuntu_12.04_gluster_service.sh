#!/bin/bash -vx

# now setup volumes for use with gluster
echo '%{HOSTS}' > /vagrant/gluster_hosts.txt
perl /vagrant/setup_gluster_peers.pl --host /vagrant/gluster_hosts.txt --dir-map /vagrant/gluster_volumes_report.txt

