#!/bin/bash -vx

# prepare a location for the DCC portal
mkdir -p /mnt/dcc-portal
cp /vagrant/settings.yml /mnt/dcc-portal/
cd /mnt/dcc-portal
# get the web app
wget %{DCC_PORTAL_JAR_URL}
# get the index
wget %{DCC_INDEX_TAR_URL}
# load the index into elasticsearch
# NOTE: I've had problems with this in the past, where elasticsearch fails for some reason
curl -XPOST 'master:9200/%{DCC_INDEX_NAME}/_import?target=/usr/local/dcc-portal/%{DCC_INDEX_NAME}&millis=600000'
# launch the portal
# FIXME: somehow this doesn't run in the backend and the provisioning script hangs on this
nohup java -Xmx4G -jar %{DCC_PORTAL_JAR_NAME} server settings.yml &

