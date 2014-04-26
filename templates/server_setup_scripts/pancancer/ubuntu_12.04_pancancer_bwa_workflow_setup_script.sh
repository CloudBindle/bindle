#!/bin/bash

cd ~seqware/released-bundles/
wget http://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_BWA_2.2.0_SeqWare_1.0.13.zip
chown seqware:seqware Workflow_Bundle_BWA_2.2.0_SeqWare_1.0.13.zip
su - seqware -c 'seqware bundle install --zip ~seqware/released-bundles/Workflow_Bundle_BWA_2.2.0_SeqWare_1.0.13.zip'
rm Workflow_Bundle_BWA_2.2.0_SeqWare_1.0.13.zip
cd -
