#!/bin/bash

cd ~seqware
wget http://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_BWA_2.1_SeqWare_1.0.11.zip
chown seqware:seqware Workflow_Bundle_BWA_2.1_SeqWare_1.0.11.zip
su - seqware -c 'seqware bundle install --zip Workflow_Bundle_BWA_2.1_SeqWare_1.0.11.zip'
rm Workflow_Bundle_BWA_2.1_SeqWare_1.0.11.zip

