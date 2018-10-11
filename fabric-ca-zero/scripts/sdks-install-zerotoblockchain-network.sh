#!/bin/bash

set -e

mkdir $HOME/developer || true
cd $HOME/developer || true
rm -Rf $HOME/developer/zerotoblockchain-network || true
cp -rf /stuff/zerotoblockchain-network $HOME/developer
cp -f /stuff/node_modules.tar.gz $HOME/developer/zerotoblockchain-network
cd $HOME/developer/zerotoblockchain-network
gunzip < node_modules.tar.gz | tar -xv
rm -f node_modules.tar.gz
#composer archive create --sourceType dir --sourceName . --archiveFile ./tutorial-network.bna
composer archive create -t dir -n .

if [[ ! -z "${http_proxy}" ]]; then
   temp_http_proxy=$http_proxy
   temp_https_proxy=$https_proxy
   temp_no_proxy=$no_proxy
   unset http_proxy
   unset https_proxy
   unset no_proxy
fi

export DEBUG=composer[debug]:*,grpc[debug]:*,verbatim[debug]:*
composer network install --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --archiveFile zerotoblockchain-network@0.1.5.bna -o affiliation=org2.mplescano.com
composer network start --networkName zerotoblockchain-network --networkVersion 0.1.5 --networkAdmin admin-peer-org2-mplescano-com --networkAdminEnrollSecret admin-peer-org2-mplescano-compw --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --file ~/zerotoblockchain-network-networkadmin.card
#A temporary work around is to ACTIVATE the card yourself
#see https://stackoverflow.com/questions/46201984/hyperledger-composer-error-the-current-identity-must-be-activated-activation
composer card import --file ~/zerotoblockchain-network-networkadmin.card
#composer identity list -c admin-peer-org2-mplescano-com@zerotoblockchain-network
sleep 60
composer identity list -c admin-peer-org2-mplescano-com@zerotoblockchain-network
composer network ping --card admin-peer-org2-mplescano-com@zerotoblockchain-network

if [[ ! -z "${temp_http_proxy}" ]]; then
   export http_proxy=$temp_http_proxy
   export https_proxy=$temp_https_proxy
   export no_proxy=$temp_no_proxy
fi

npm install

if [[ ! -z "${http_proxy}" ]]; then
   temp_http_proxy=$http_proxy
   temp_https_proxy=$https_proxy
   temp_no_proxy=$no_proxy
   unset http_proxy
   unset https_proxy
   unset no_proxy
fi

npm run test
