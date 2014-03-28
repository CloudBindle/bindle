#!/bin/bash

cd ~seqware
wget http://s3.amazonaws.com/oicr.workflow.bundles/released-bundles/Workflow_Bundle_PanCancer_BWA_Mem_2.1-SNAPSHOT_SeqWare_1.0.11.zip
chmown seqware:seqware Workflow_Bundle_PanCancer_BWA_Mem_2.1-SNAPSHOT_SeqWare_1.0.11.zip
su - seqware -c 'seqware bundle install --zip Workflow_Bundle_PanCancer_BWA_Mem_2.1-SNAPSHOT_SeqWare_1.0.11.zip'

