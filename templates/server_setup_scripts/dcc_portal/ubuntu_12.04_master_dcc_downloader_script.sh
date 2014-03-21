#!/bin/bash -vx

# setup hosts
hostname %{HOST}

# basic tools
export DEBIAN_FRONTEND=noninteractive


# prepare a location for the DCC Downloader
mkdir -p /mnt/dcc-downloader
cd /mnt/dcc-downloader

HADOOP_USER_NAME=hdfs hdfs dfs -mkdir -p /icgc/download
HADOOP_USER_NAME=hdfs hdfs dfs -chown downloader /icgc/download
HADOOP_USER_NAME=downloader hdfs dfs -mkdir -p /icgc/download/dynamic
HADOOP_USER_NAME=downloader hdfs dfs -mkdir -p /icgc/download/static

HADOOP_USER_NAME=hdfs hdfs dfs -chown downloader /user/downloader

HADOOP_USER_NAME=hdfs hdfs dfs -mkdir -p /user/downloader
HADOOP_USER_NAME=hdfs hdfs dfs -chown downloader /user/downloader

# install scala
wget www.scala-lang.org/files/archive/scala-2.10.3.deb
dpkg -i scala-2.10.3.deb

# get downloader jar
wget %{DCC_DOWNLOADER_JAR_URL}
ln -s %{DCC_DOWNLOADER_JAR} dcc-downloader.jar

# download configuration
wget %{DCC_DOWNLOADER_CONFIG_URL}
mkdir dcc-downloader-config
tar -xvf %{DCC_DOWNLOADER_CONFIG_TAR} -C dcc-downloader-config --strip-components=1
chmod u+x dcc-downloader-config/*.sh

# setup hbase filter
wget %{DCC_DOWNLOADER_FILTER_JAR_URL}
mkdir dcc-downloader-filter
mv %{DCC_DOWNLOADER_FILTER_JAR} dcc-downloader-filter/
ln -s %{DCC_DOWNLOADER_FILTER_JAR} dcc-downloader-filter/filter.jar

# setup workflow
wget %{DCC_DOWNLOADER_WORKFLOW_URL}
mkdir dcc-downloader-workflows
tar -xvf %{DCC_DOWNLOADER_WORKFLOW_TAR} -C dcc-downloader-workflows --strip-components=1
HADOOP_USER_NAME=downloader hdfs dfs -put dcc-downloader-workflows workflows

#apply all configurations to Hadoop system and restart the components
cp dcc-downloader-config/hbase-env.sh /etc/hbase/conf/
cp dcc-downloader-config/oozie-site.xml /etc/oozie/conf/
cp dcc-downloader-config/mapred-site.xml /etc/hadoop/conf/


# download all necessary files
wget %{DCC_DOWNLOADER_DYNAMIC_INDEX_URL}
mkdir dcc-downloader-dynamic
tar -xvf %{DCC_DOWNLOADER_DYNAMIC_INDEX_TAR} -C dcc-downloader-dynamic --strip-components=1
HADOOP_USER_NAME=downloader hdfs dfs -put dcc-downloader-dynamic /user/downloader/dynamic
/mnt/dcc-downloader/dcc-downloader-config/DownloaderImport.sh

# setup static download
wget %{DCC_DOWNLOADER_STATIC_INDEX_URL}
mkdir dcc-downloader-static
tar -xvf %{DCC_DOWNLOADER_STATIC_INDEX_TAR} -C dcc-downloader-static --strip-components=1
HADOOP_USER_NAME=downloader hdfs dfs -put dcc-downloader-static/* /icgc/download/static

service hadoop-init restart
