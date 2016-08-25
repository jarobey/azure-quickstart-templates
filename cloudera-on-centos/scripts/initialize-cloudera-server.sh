#!/usr/bin/env bash

execname=$0

log() {
  echo "$(date): [${execname}] $@" >> /tmp/initialize-cloudera-server.log
}

#fail on any error
set -e

ClusterName=$1
key=$2
mip=$3
worker_ip=$4
HA=$5
User=$6
Password=$7

cmUser=$8
cmPassword=$9

dbHost=${10}
dbAdminUser=${11}
dbAdminPass=${12}

EMAILADDRESS=${13}
BUSINESSPHONE=${14}
FIRSTNAME=${15}
LASTNAME=${16}
JOBROLE=${17}
JOBFUNCTION=${18}
COMPANY=${19}
VMSIZE=${20}

log "BEGIN: master node deployments"

log "Beginning process of disabling SELinux"

log "Running as $(whoami) on $(hostname)"

# Use the Cloudera-documentation-suggested workaround
log "about to set setenforce to 0"
set +e
setenforce 0 >> /tmp/setenforce.out

exitcode=$?
log "Done with settiing enforce. Its exit code was $exitcode"

log "Running setenforce inline as $(setenforce 0)"

getenforce
log "Running getenforce inline as $(getenforce)"
getenforce >> /tmp/getenforce.out

log "should be done logging things"


cat /etc/selinux/config > /tmp/beforeSelinux.out
log "ABOUT to replace enforcing with disabled"
sed -i 's^SELINUX=enforcing^SELINUX=disabled^g' /etc/selinux/config || true

cat /etc/selinux/config > /tmp/afterSeLinux.out
log "Done disabling selinux"

set +e

log "Set cloudera-manager.repo to CM v5"
yum clean all >> /tmp/initialize-cloudera-server.log
rpm --import http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera >> /tmp/initialize-cloudera-server.log
wget http://archive.cloudera.com/cm5/redhat/6/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo >> /tmp/initialize-cloudera-server.log
# this often fails so adding retry logic
n=0
until [ $n -ge 5 ]
do
    yum install -y oracle-j2sdk* cloudera-manager-daemons cloudera-manager-server >> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err && break
    n=$[$n+1]
    sleep 15s
done
if [ $n -ge 5 ]; then log "scp error $remote, exiting..." & exit 1; fi

#######################################################################################################################
log "Connecting to external DB"
wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.39.tar.gz >> /tmp/initialize-cloudera-server.log
tar zxvf mysql-connector-java-5.1.39.tar.gz >> /tmp/initialize-cloudera-server.log
cp mysql-connector-java-5.1.39/mysql-connector-java-5.1.39-bin.jar /usr/share/java/mysql-connector-java.jar
echo "installing mysql"
wget https://dev.mysql.com/get/Downloads/MySQL-5.6/MySQL-5.6.26-1.el6.x86_64.rpm-bundle.tar
tar -xvf MySQL-5.6.26-1.el6.x86_64.rpm-bundle.tar
curlib=$(rpm -qa |grep mysql-libs-)
rpm -e --nodeps $curlib
rpm -ivh MySQL-client-5.6.26-1.el6.x86_64.rpm
wget http://dev.mysql.com/get/Downloads/Connector-Python/mysql-connector-python-2.0.4-1.el6.noarch.rpm
rpm -ivh mysql-connector-python-2.0.4-1.el6.noarch.rpm
wget http://dev.mysql.com/get/Downloads/MySQLGUITools/mysql-utilities-1.5.5-1.el6.noarch.rpm
rpm -ivh mysql-utilities-1.5.5-1.el6.noarch.rpm
bash setup-mysql.sh $dbHost $dbAdminUser $dbAdminPass >> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err

log "finished installing external DB"
#######################################################################################################################

log "start cloudera-scm-server services"
#service cloudera-scm-server-db start >> /tmp/initialize-cloudera-server.log
service cloudera-scm-server start >> /tmp/initialize-cloudera-server.log

#log "Create HIVE metastore DB Cloudera embedded PostgreSQL"
#export PGPASSWORD=$(head -1 /var/lib/cloudera-scm-server-db/data/generated_password.txt)
#SQLCMD=( """CREATE ROLE hive LOGIN PASSWORD 'hive';""" """CREATE DATABASE hive OWNER hive ENCODING 'UTF8';""" """ALTER DATABASE hive SET standard_conforming_strings = off;""" )
#for SQL in "${SQLCMD[@]}"; do
#	psql -A -t -d scm -U cloudera-scm -h localhost -p 5432 -c "${SQL}" >> /tmp/initialize-cloudera-server.log
#done
while ! (exec 6<>/dev/tcp/$(hostname)/7180) ; do log 'Waiting for cloudera-scm-server to start...'; sleep 15; done
log "END: master node deployments"



# Set up python
rpm -ivh http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm >> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err
yum -y install python-pip >> /tmp/initialize-cloudera-server.log
pip install cm_api >> /tmp/initialize-cloudera-server.log

# trap file to indicate done
log "creating file to indicate finished"
touch /tmp/readyFile

# Execute script to deploy Cloudera cluster
log "BEGIN: CM deployment - starting"
log "Parameters: $ClusterName $mip $worker_ip $EMAILADDRESS $BUSINESSPHONE $FIRSTNAME $LASTNAME $JOBROLE $JOBFUNCTION $COMPANY $VMSIZE"
if $HA; then
    python cmxDeployOnIbiza.py -n "$ClusterName" -u $User -p $Password  -m "$mip" -w "$worker_ip" -a -c $cmUser -s $cmPassword -e -r "$EMAILADDRESS" -b "$BUSINESSPHONE" -f "$FIRSTNAME" -t "$LASTNAME" -o "$JOBROLE" -i "$JOBFUNCTION" -y "$COMPANY" -v "$VMSIZE">> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err
else
    python cmxDeployOnIbiza.py -n "$ClusterName" -u $User -p $Password  -m "$mip" -w "$worker_ip" -c $cmUser -s $cmPassword -e -r "$EMAILADDRESS" -b "$BUSINESSPHONE" -f "$FIRSTNAME" -t "$LASTNAME" -o "$JOBROLE" -i "$JOBFUNCTION" -y "$COMPANY" -v "$VMSIZE">> /tmp/initialize-cloudera-server.log 2>> /tmp/initialize-cloudera-server.err
fi
log "END: CM deployment ended"
