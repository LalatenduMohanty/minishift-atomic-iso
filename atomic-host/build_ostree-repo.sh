#!/bin/bash


## Run the script from /srv (or other HomeDir, if you change the value
## below) like so:
##
## bash sig-atomic-buildscripts/build_ostree_components.sh /srv/builddir
## 
## Other files to edit/check:
##
## atomic-7.1.tdl must point to an install tree avail over http,
## there's a hard-coded IP address there now
## 
## atomic-7.1-cloud.ks and atomic-7.1-vagrant.ks must point to
## the desired ostree repo in line beginning w/ "ostreesetup"

VERSION=7.$( date  +%Y%m%d )

DateStamp=$( date  +%Y%m%d_%H%M%S )
BuildDir=$1
LogFile=${BuildDir}/log
mkdir -p ${BuildDir}
# Make it absolute
BuildDir=$(cd $BuildDir && pwd)
GitDir=$(pwd)
OstreeRepoDir=/${BuildDir}/repo && mkdir -p $OstreeRepoDir
ln -s ${OstreeRepoDir} ${BuildDir}/repo

set -x
set -e
set -o pipefail

cd ${BuildDir}

# Init, make sure we have the bits we need installed. 
cp -f ${GitDir}/rhel-atomic-rebuild.repo /etc/yum.repos.d/
yum -y install ostree rpm-ostree glib2 docker libvirt epel-release

cp -f ${GitDir}/atomic7-testing.repo /etc/yum.repos.d/
echo 'enabled=0' >> /etc/yum.repos.d/atomic7-testing.repo
yum --enablerepo=atomic7-testing -y install rpm-ostree-toolbox

service firewalld stop

## create repo in BuildDir, this will fail w/o issue if already exists

if ! test -d ${BuildDir}/repo/objects; then
    ostree --repo=${BuildDir}/repo init --mode=archive-z2
fi

# sync repo from ds location : enable this if you want to build on top of the Official CentOS Atomic Host Tree - most people will NOT want this.
#ostree remote add --repo=/${BuildDir}/repo centos-atomic-host --set=gpg-verify=false http://mirror.centos.org/centos/7/atomic/x86_64/repo && ostree pull --depth=-1 --repo=/${BuildDir}/repo --mirror centos-atomic-host centos-atomic-host/7/x86_64/standard

## compose a new tree, based on defs in centos-atomic-host.json

rpm-ostree compose --repo=${OstreeRepoDir} tree --add-metadata-string=version=${VERSION} ${GitDir}/centos-atomic-host.json |& tee ${BuildDir}/log.compose
if ostree --repo=${OstreeRepoDir} rev-parse centos-atomic-host/7/x86_64/standard^ &>/dev/null; then
    ostree --repo=${OstreeRepoDir} static-delta generate centos-atomic-host/7/x86_64/standard
fi
ostree --repo=${OstreeRepoDir} summary -u |& tee ${BuildDir}/log.compose

# deal with https://bugzilla.gnome.org/show_bug.cgi?id=748959
chmod -R a+r /${BuildDir}/repo/objects

echo 'Stage-1 done, you can now build the delivery images from build_stage2.sh'

