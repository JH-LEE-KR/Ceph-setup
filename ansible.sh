#!/bin/bash --init-file

# DeepOps setup/bootstrap script
#   This script installs required dependencies on a system so it can run Ansible
#   and initializes the DeepOps directory
#
# Can be run standalone with: curl -sL bit.ly/nvdeepops | bash
#                         or: curl -sL bit.ly/nvdeepops | bash -s -- 19.07
# ------------------------------------------
# Modification:
# Added code for setup Ceph VENV
# -- Jaeho Lee, dlwogh9344@khu.ac.kr
# ------------------------------------------

# Determine current directory and root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="${SCRIPT_DIR}/.."

# Configuration
ANSIBLE_VERSION="${ANSIBLE_VERSION:-2.10.0}"    # Ansible version to install
ANSIBLE_TOO_NEW="${ANSIBLE_TOO_NEW:-2.11.0}"    # Ansible version too new
PIP="${PIP:-pip3}"                              # Pip binary to use
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3}"    # Python3 path
VENV_DIR="${VENV_DIR:-/opt/ceph/ceph-env}"      # Path to python virtual environment to create

# Set distro-specific variables
PROXY_USE=`grep -v ^# ${SCRIPT_DIR}/proxy.sh 2>/dev/null | grep -v ^$ | wc -l`

# Disable interactive prompts from Apt
export DEBIAN_FRONTEND=noninteractive

# Exit if run as root
if [ $(id -u) -eq 0 ] ; then
    echo "Please run as a regular user"
    exit
fi

# Proxy wrapper
as_user(){
    if [ $PROXY_USE -gt 0 ] ; then
        cmd="bash -c '. ${SCRIPT_DIR}/proxy.sh && $@'"
    else
        cmd="bash -c '$@'"
    fi
    eval $cmd
}

# Create virtual environment and install python dependencies
if command -v virtualenv &> /dev/null ; then
    echo "Create virtual environment"
    sudo mkdir -p "${VENV_DIR}"
    sudo chown -R $(id -u):$(id -g) "${VENV_DIR}"
    deactivate nondestructive &> /dev/null
    virtualenv -q --python="${PYTHON_BIN}" "${VENV_DIR}"
    . "${VENV_DIR}/bin/activate"
    as_user "${PIP} install -q --upgrade pip"

    # Check for any installed ansible pip package
    if pip show ansible 2>&1 >/dev/null; then
        current_version=$(pip show ansible | grep Version | awk '{print $2}')
	echo "Current version of Ansible is ${current_version}"
	if "${PYTHON_BIN}" -c "from distutils.version import LooseVersion; print(LooseVersion('$current_version') >= LooseVersion('$ANSIBLE_TOO_NEW'))" | grep True 2>&1 >/dev/null; then
            echo "Ansible version ${current_version} too new for DeepOps"
	    echo "Please uninstall any ansible, ansible-base, and ansible-core packages and re-run this script"
	    exit 1
	fi
	if "${PYTHON_BIN}" -c "from distutils.version import LooseVersion; print(LooseVersion('$current_version') < LooseVersion('$ANSIBLE_VERSION'))" | grep True 2>&1 >/dev/null; then
	    echo "Ansible will be upgraded from ${current_version} to ${ANSIBLE_VERSION}"
	fi
    fi
    echo "Install ansible and required packages"
    as_user "${PIP} install -q --upgrade \
        ansible==${ANSIBLE_VERSION} \
        netaddr \
        six"
else
    echo "ERROR: Unable to create Python virtual environment, 'virtualenv' command not found"
    exit 1
fi

# Install Ansible Galaxy Third-party Collections
if command -v ansible-galaxy &> /dev/null ; then
    echo "Copy requirements"
    as_user cp "${ROOT_DIR}/requirements.yml" "${SCRIPT_DIR}" 

    as_user ansible-galaxy install -r requirements.yml >/dev/null

else
    echo "ERROR: Unable to install Ansible Galaxy Collections, 'ansible-galaxy' command not found"
fi

echo
echo "*** Setup complete ***"
echo "To use Ansible, run: source ${VENV_DIR}/bin/activate"
echo
