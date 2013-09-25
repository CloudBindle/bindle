#!/bin/bash -vx

# prepare a location for the DCC portal
mkdir -p /usr/local/dcc-portal
cp /vagrant/settings.yml /usr/local/dcc-portal/
cd /usr/local/dcc-portal
# get the web app
# as of 20130925
wget http://ca.on.oicr.icgc.s3.amazonaws.com/lib/dcc-portal-api-1.11-20130924.184611-237.jar
# get the index
# as of 20130925
wget http://ca.on.oicr.icgc.s3.amazonaws.com/index_dumps/dcc-release-load-dev-06e-6-37.tar.gz
# load the index into elasticsearch
# NOTE: I've had problems with this in the past, where elasticsearch fails for some reason
# as of 20130925
curl -XPOST 'master:9200/dcc-release-load-dev-06e-6-37/_import?target=/usr/local/dcc-portal/dcc-release-load-dev-06e-6-37&millis=600000' &> es_load.log
# launch the portal
# FIXME: somehow this doesn't run in the backend and the provisioning script hangs on this
# as of 20130925
nohup java -Xmx4G -jar dcc-portal-api-1.11-20130924.184611-237.jar server settings.yml &

