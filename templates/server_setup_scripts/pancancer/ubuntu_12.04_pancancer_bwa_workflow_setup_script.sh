#!/bin/bash

VERSION=2.4.0
SWVERSION=1.0.13
cd ~seqware/released-bundles/
wget http://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_BWA_${VERSION}_SeqWare_${SWVERSION}.zip
chown seqware:seqware Workflow_Bundle_BWA_${VERSION}_SeqWare_${SWVERSION}.zip
su - seqware -c 'seqware bundle install --zip ~seqware/released-bundles/Workflow_Bundle_BWA_${VERSION}_SeqWare_${SWVERSION}.zip'
rm Workflow_Bundle_BWA_${VERSION}_SeqWare_${SWVERSION}.zip
cd -
