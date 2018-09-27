#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Usage:
#
# ./prereqs-ubuntu.sh
#
# User must then logout and login upon completion of script
#

# Exit on any failure
set -e

export VERSION_FABRIC=1.2.0
export CA_VERSION_FABRIC=1.2.0
export ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')")
export MARCH=$(uname -m)
CA_BINARY_FILE_FABRIC=hyperledger-fabric-ca-${ARCH}-${CA_VERSION_FABRIC}.tar.gz
BINARY_FILE_FABRIC=hyperledger-fabric-${ARCH}-${VERSION_FABRIC}.tar.gz

# Array of supported versions
declare -a versions=('trusty' 'xenial' 'yakkety');

# check the version and extract codename of ubuntu if release codename not provided by user
if [ -z "$1" ]; then
    source /etc/lsb-release || \
        (echo "Error: Release information not found, run script passing Ubuntu version codename as a parameter"; exit 1)
    CODENAME=${DISTRIB_CODENAME}
else
    CODENAME=${1}
fi

# check version is supported
if echo ${versions[@]} | grep -q -w ${CODENAME}; then
    echo "Installing Hyperledger Composer prereqs for Ubuntu ${CODENAME}"
else
    echo "Error: Ubuntu ${CODENAME} is not supported"
    exit 1
fi

# Update package lists
echo "# Updating package lists"
apt-get update
apt-get install -y sudo nano software-properties-common curl
#sudo -E apt-add-repository -y ppa:git-core/ppa
sudo -E apt-get update

# Install Git
echo "# Installing Git"
sudo -E apt-get install -y git

# Install nvm dependencies
echo "# Installing nvm dependencies"
sudo -E apt-get -y install build-essential libssl-dev

# Ensure that CA certificates are installed
sudo -E apt-get -y install apt-transport-https ca-certificates

# Install kernel packages which allows us to use aufs storage driver if V14 (trusty/utopic)
if [ "${CODENAME}" == "trusty" ]; then
    echo "# Installing required kernel packages"
    sudo -E apt-get -y install linux-image-extra-$(uname -r) linux-image-extra-virtual
fi

# Install python v2 if required
set +e
COUNT="$(python -V 2>&1 | grep -c 2.)"
if [ ${COUNT} -ne 1 ] || ! [ -x "$(command -v python)" ]
then
   sudo -E apt-get install -y python2.7 python-pip
   sudo -E apt install -y python3-pip
fi

# Install unzip, required to install hyperledger fabric.
sudo -E apt-get -y install unzip

echo "File:/${ARCH}-${VERSION_FABRIC}/${BINARY_FILE_FABRIC}"
curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/${ARCH}-${VERSION_FABRIC}/${BINARY_FILE_FABRIC} | tar xz

# Install fabric ca client
echo "File:/${ARCH}-${CA_VERSION_FABRIC}/${CA_BINARY_FILE_FABRIC}"
curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric-ca/hyperledger-fabric-ca/${ARCH}-${CA_VERSION_FABRIC}/${CA_BINARY_FILE_FABRIC} | tar xz
#cp /usr/local/bin/fabric-ca-client

# Print installation details for user
echo ''
echo 'Installation completed, versions installed are:'
echo ''
echo -n 'Python:         '
python -V

sudo -E apt-get -y install openjdk-8-jdk
sudo -E apt-get -y install gradle
sudo -E apt-get -y install golang
sudo -E apt-get -y install acl
#sudo -E apt-get-y  install firefox
#curl -LO https://github.com/browsh-org/browsh/releases/download/v1.4.13/browsh_1.4.13_linux_amd64.deb
#sudo -E apt-get -y install ./browsh_1.4.13_linux_amd64.deb
#rm ./browsh_1.4.13_linux_amd64.deb
#sudo -E apt-get -y install lynx

# Print reminder of need to logout in order for these changes to take effect!
echo ''
echo "Please logout then login before continuing."
