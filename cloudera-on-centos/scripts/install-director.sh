#!/bin/bash

echo "installing java"
sudo yum localinstall jdk-version-linux-x64.rpm

echo "updating yum local repository"
cd /etc/yum.repos.d/
sudo wget "http://archive.cloudera.com/director/redhat/6/x86_64/director/cloudera-director.repo"

echo "installing director server and client"
sudo yum install cloudera-director-server cloudera-director-client

echo "start the service"
sudo service cloudera-director-server start

echo "update iptables"
sudo service iptables save 
sudo chkconfig iptables off 
sudo service iptables stop