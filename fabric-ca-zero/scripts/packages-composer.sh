#!/bin/bash

#Exit on any failure
set -e

# Set up nvm environment without restarting the shell
export NVM_DIR="${HOME}/.nvm"
[ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
[ -s "${NVM_DIR}/bash_completion" ] && . "${NVM_DIR}/bash_completion"

if [[ ! -z "${http_proxy}" ]]; then
  export HTTPS_PROXY="${https_proxy}"
  export HTTP_PROXY="${http_proxy}"
  export NO_PROXY="${no_proxy}"
fi

npm config set strict-ssl false
npm config set registry "http://registry.npmjs.org/"

npm install -g composer-cli@0.20
npm install -g composer-rest-server@0.20
npm install -g generator-hyperledger-composer@0.20
npm install -g yo
npm install -g composer-playground@0.20
mkdir ~/fabric-dev-servers && cd ~/fabric-dev-servers
curl -O https://raw.githubusercontent.com/hyperledger/composer-tools/master/packages/fabric-dev-servers/fabric-dev-servers.tar.gz
tar -xvf fabric-dev-servers.tar.gz

#composer-playground
