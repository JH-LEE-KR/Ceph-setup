#!/bin/bash

# Determine current directory and root directory
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Configuration
CEPH_TAG="${CEPH_TAG:-stable-6.0}"    # DeepOps branch to set up

# Set distro-specific variables
PROXY_USE=`grep -v ^# ${ROOT_DIR}/proxy.sh 2>/dev/null | grep -v ^$ | wc -l`

# Proxy wrapper
as_user(){
    if [ $PROXY_USE -gt 0 ] ; then
        cmd="bash -c '. ${ROOT_DIR}/proxy.sh && $@'"
    else
        cmd="bash -c '$@'"
    fi
    eval $cmd
}

# Clone ceph-ansible Repository
if ! (cd "${ROOT_DIR}" && test -d ceph-ansible >/dev/null 2>&1 ) ; then
    if command -v git &> /dev/null ; then
        if ! test -d ceph-ansible ; then
            echo "Clone ceph-ansible repo"
            as_user git clone https://github.com/ceph/ceph-ansible.git
        fi
        cd ceph-ansible
        if command -v git &> /dev/null ; then
            echo "Git checkout branch"
            as_user git checkout ${CEPH_TAG}
        fi
    else
        echo "ERROR: Unable to check out ceph-ansible git repo, 'git' command not found"
        exit
    fi
fi

# Set ceph-ansible directory
CEPH_DIR="${ROOT_DIR}/ceph-ansible"

# Copy scripts
if ! (cd "${CEPH_DIR}" && test -d scripts >/dev/null 2>&1 ) ; then
    mkdir scripts
    mv $ROOT_DIR/*.sh $CEPH_DIR/scripts
fi

# Update path
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Run ansible setup script
if (cd "${ROOT_DIR}/scripts" && test -e ansible.sh >/dev/null 2>&1 ) ; then
    echo "Run ansible setup script"
    cd $ROOT_DIR
    as_user ./scripts/ansible.sh 2>&1
else
    echo "ERROR: Unable to run ansible setup script"
    exit
fi