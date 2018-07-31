#!/usr/bin/env bash
##
## bootstrap.sh
##

## --- CHANGE HERE! ---
PUB_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHyL/Bvo5WBfsSMg35YBwPfncjKbrHRM54YC4di/afuk ansible@centos7-01'



## ================================================================
##
## Variables
##
## ================================================================
BACKUP_DIR=/root/backup
USER_NAME=ansible
GROUP_NAME=wheel
MAIN_TARGET=centos7-02



## ================================================================
##
## Flags
##
## ================================================================

## For Ansible
ANSIBLE_FLAG=0
ANSIBLE_TARGET=${MAIN_TARGET}
if [ `uname -n` == ${ANSIBLE_TARGET} ]; then
    ANSIBLE_FLAG=1
fi

## For ECL CLI
ECL_FLAG=0
ECLCLI_TARGET=${MAIN_TARGET}
if [ `uname -n` == ${ECLCLI_TARGET} ]; then
    ECL_FLAG=1
fi



## ================================================================
##
## Functions
##
## ================================================================
backup_file () {
    if [ $# -ne 2 ]; then
	echo "usage: $0 <target> <backup>"
	exit 1
    fi
    TARGET_FILE=$1
    BACKUP_FILE=$2

    cp -fv --preserve=all ${TARGET_FILE} ${BACKUP_FILE}
    ls -l ${TARGET_FILE} ${BACKUP_FILE}
    ls -Z ${TARGET_FILE} ${BACKUP_FILE}

    return 0
}



## ================================================================
##
## Main
##
## ================================================================

## ------------------------------------------------
## Make backup directory
## ------------------------------------------------
if [ ! -d ${BACKUP_DIR} ]; then
    mkdir -v ${BACKUP_DIR}
    ls -ld ${BACKUP_DIR}
    ls -dZ ${BACKUP_DIR}
fi

## ------------------------------------------------
## Add user
## ------------------------------------------------
id ${USER_NAME} &>/dev/null
RET=$?
if [ ${RET} -ne 0 ]; then
    useradd -g ${GROUP_NAME} -m -r ${USER_NAME}
    base64 /dev/urandom | fold -w 32 | head -n 1 | passwd --stdin ${USER_NAME}
    id ${USER_NAME}
fi

## ------------------------------------------------
## Add sudoers
## ------------------------------------------------
SUDOERS_FILE=/etc/sudoers.d/${USER_NAME}
if [ ! -r ${SUDOERS_FILE} ]; then
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" > ${SUDOERS_FILE}
    chmod -v 0440 ${SUDOERS_FILE}
    ls -l ${SUDOERS_FILE}
fi

## ------------------------------------------------
## Put SSH Key
## ------------------------------------------------
USER_HOME=`getent passwd | grep -F "${USER_NAME}" | awk -F ':' '{print $6}'`
SSH_DIR=${USER_HOME}/.ssh
if [ ! -d ${SSH_DIR} ]; then
    mkdir -vm 0700 ${SSH_DIR}
fi

cd ${SSH_DIR}; pwd
if [ ! -r authorized_keys ]; then
    echo ${PUB_KEY} > authorized_keys
    chmod -v 0600 authorized_keys
    chown -Rv ${USER_NAME}:${GROUP_NAME} .
    ls -ld .
    ls -dZ .
    ls -lAR .
    ls -ARZ .
fi

## ------------------------------------------------
## Set PAM
## ------------------------------------------------
cd /etc/pam.d; pwd
TARGET_FILE=su
grep -F 'pam_wheel.so use_uid' ${TARGET_FILE} | grep -v -E '^#' &>/dev/null
RET=$?
if [ ${RET} -ne 0 ]; then
    BACKUP_FILE=${BACKUP_DIR}/${TARGET_FILE}.`date +%Y%m%d`
    backup_file ${TARGET_FILE} ${BACKUP_FILE}

    sed -i \
	-e 's/#auth\t\trequired/auth\t\trequired/g' \
	${TARGET_FILE}
    diff -u ${BACKUP_FILE} ${TARGET_FILE}
fi

## ------------------------------------------------
## Add hosts record
## ------------------------------------------------
cd /etc; pwd
TARGET_FILE=hosts
grep -F '192.168.56.' ${TARGET_FILE} &>/dev/null
RET=$?
if [ ${RET} -ne 0 ]; then
    BACKUP_FILE=${BACKUP_DIR}/${TARGET_FILE}.`date +%Y%m%d`
    backup_file ${TARGET_FILE} ${BACKUP_FILE}

    cat <<- EOF >> ${TARGET_FILE}
	192.168.56.120	centos7-08	centos7-08.localdomain
	192.168.56.121	centos7-07	centos7-07.localdomain
	192.168.56.122	centos7-06	centos7-06.localdomain
	192.168.56.123	centos7-05	centos7-05.localdomain
	192.168.56.124	centos7-04	centos7-04.localdomain
	192.168.56.125	centos7-03	centos7-03.localdomain
	192.168.56.126	centos7-02	centos7-02.localdomain
	192.168.56.127	centos7-01	centos7-01.localdomain
EOF
    diff -u ${BACKUP_FILE} ${TARGET_FILE}
fi

## ------------------------------------------------
## Change YUM mirror
## ------------------------------------------------
cd /etc/yum.repos.d; pwd
TARGET_FILE=CentOS-Base.repo
grep -i iij ${TARGET_FILE} &>/dev/null
RET=$?
if [ ${RET} -ne 0 ]; then
    BACKUP_FILE=${BACKUP_DIR}/${TARGET_FILE}.`date +%Y%m%d`
    backup_file ${TARGET_FILE} ${BACKUP_FILE}

    sed -i \
	-e 's/^mir/#mir/g' \
	-e 's/^#base/base/g' \
	-e 's|mirror\.centos\.org|ftp.iij.ad.jp/pub/linux|g' \
	${TARGET_FILE}
    diff -u ${BACKUP_FILE} ${TARGET_FILE}
fi

## ------------------------------------------------
## Update system
##
## Bug 1566502 - nmcli cannot modify interface
## https://bugzilla.redhat.com/show_bug.cgi?id=1566502
##
## glibc-common: For Japanese environment
## gcc kernel-devel: For VirtualBox Guest Additions
## emacs-nox screen: For personal reasons
## ------------------------------------------------
rm -frv /var/cache/yum
yum -y upgrade
systemctl restart NetworkManager
yum -y reinstall glibc-common
yum -y install gcc kernel-devel emacs-nox screen

## ------------------------------------------------
## Install Ansible, Serverspec and Infrataster
## ------------------------------------------------
if [ ${ANSIBLE_FLAG} -ne 0 ]; then
    yum -y install epel-release centos-release-scl-rh

    ## ------------------------------------------------
    ## Change YUM mirror for EPEL
    ## ------------------------------------------------
    cd /etc/yum.repos.d; pwd
    TARGET_FILE=epel.repo
    grep -i iij ${TARGET_FILE} &>/dev/null
    RET=$?
    if [ ${RET} -ne 0 ]; then
	BACKUP_FILE=${BACKUP_DIR}/${TARGET_FILE}.`date +%Y%m%d`
	backup_file ${TARGET_FILE} ${BACKUP_FILE}

	sed -i \
	    -e 's/^meta/#meta/g' \
	    -e 's/^#base/base/g' \
	    -e 's|download\.fedoraproject\.org/pub|ftp.iij.ad.jp/pub/linux/fedora|g' \
	    ${TARGET_FILE}
	diff -u ${BACKUP_FILE} ${TARGET_FILE}
    fi

    ## ------------------------------------------------
    ## Change YUM mirror for SCL
    ## ------------------------------------------------
    cd /etc/yum.repos.d; pwd
    TARGET_FILE=CentOS-SCLo-scl-rh.repo
    grep -i iij ${TARGET_FILE} &>/dev/null
    RET=$?
    if [ ${RET} -ne 0 ]; then
	BACKUP_FILE=${BACKUP_DIR}/${TARGET_FILE}.`date +%Y%m%d`
	backup_file ${TARGET_FILE} ${BACKUP_FILE}

	sed -i \
	    -e 's|mirror\.centos\.org|ftp.iij.ad.jp/pub/linux|g' \
	    ${TARGET_FILE}
	diff -u ${BACKUP_FILE} ${TARGET_FILE}
    fi

    ## ------------------------------------------------
    ## Install packages
    ## ------------------------------------------------
    rm -frv /var/cache/yum
    yum -y install \
	ansible \
	zlib-devel \
	rh-git29 \
	rh-ruby25-rubygem-bundler \
	rh-ruby25-rubygem-rake \
	rh-ruby25-ruby-devel
    echo 'alias git="LD_LIBRARY_PATH=${LIBRARY_PATH} git"' | tee -a /home/ansible/.bashrc

    ## ------------------------------------------------
    ## Enable Software Collections
    ## ------------------------------------------------
    cd /etc/profile.d; pwd
    scl -l | while read LINE
    do
	echo "source scl_source enable ${LINE}" | sudo tee ${LINE}.sh
    done
    ls -ltr *.sh
    ls -trZ *.sh

    ## ------------------------------------------------
    ## Install Serverspec and Infrataster
    ## ------------------------------------------------
    cd /usr/local/src; pwd
    scl enable rh-ruby25 'bundle init'
    TARGET_FILE=Gemfile
    cat <<- EOF >> ${TARGET_FILE}
	gem 'rbnacl', '>= 3.2', '< 5.0', :require => false
	gem 'rbnacl-libsodium', '< 1.0.16', :require => false
	gem 'bcrypt_pbkdf', '>= 1.0', '< 2.0', :require => false
	gem 'serverspec'
	gem 'infrataster'
	gem 'awspec'
EOF
    scl enable rh-git29 rh-ruby25 bundle
fi

## ------------------------------------------------
## Install Python modules
## ------------------------------------------------
if [ ${ECL_FLAG} -ne 0 ]; then

    ## ------------------------------------------------
    ## Install package
    ## https://ecl.ntt.com/documents/tutorials/eclc/rsts/installation.html
    ## ------------------------------------------------
    yum -y install gcc python-devel python-virtualenv

    ## ------------------------------------------------
    ## Install pip
    ## ------------------------------------------------
    cd /usr/local/sbin; pwd
    curl -O https://bootstrap.pypa.io/get-pip.py
    chmod -v a+x get-pip.py
    ls -l get-pip.py

    ## ------------------------------------------------
    ## Install eclcli, and upgrade six
    ## ------------------------------------------------
    ./get-pip.py
    which pip easy_install
    pip install \
        ansible-tower-cli \
        recommonmark \
        sphinx \
        sphinx_rtd_theme \
        sphinxcontrib-blockdiag \
        sphinxcontrib-seqdiag \
        sphinxcontrib-actdiag \
        sphinxcontrib-nwdiag
fi

## ------------------------------------------------
## Clean up YUM cache
## ------------------------------------------------
rm -frv /var/cache/yum

## ------------------------------------------------
## Set locale
## ------------------------------------------------
localectl set-locale LANG=ja_JP.UTF-8
localectl set-keymap jp106
localectl set-keymap jp-OADG109A
localectl status

## ------------------------------------------------
## Set timezone
## ------------------------------------------------
timedatectl set-timezone Asia/Tokyo
timedatectl status
chronyc -n sources

## ------------------------------------------------
## Reboot system
## ------------------------------------------------
systemctl reboot
