#!/bin/bash

set -e

mkdir $HOME/developer || true
cd $HOME/developer || true
rm -Rf $HOME/developer/zerotoblockchain-network
rm -Rf $HOME/developer/zerotoblockchain-network.tar.gz
cp -f /data/zerotoblockchain-network.tar.gz $HOME/developer
gunzip < zerotoblockchain-network.tar.gz | tar -xv
cd $HOME/developer/zerotoblockchain-network
rm -Rf dist/
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
composer network install --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --archiveFile zerotoblockchain-network@0.1.5.bna
composer network start --networkName zerotoblockchain-network --networkVersion 0.1.5 --networkAdmin admin-peer-org2-mplescano-com --networkAdminEnrollSecret admin-peer-org2-mplescano-compw --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --file ~/zerotoblockchain-network-networkadmin.card
#A temporary work around is to ACTIVATE the card yourself
#see https://stackoverflow.com/questions/46201984/hyperledger-composer-error-the-current-identity-must-be-activated-activation
composer card import --file ~/zerotoblockchain-network-networkadmin.card
composer identity list -c admin-peer-org2-mplescano-com@zerotoblockchain-network
composer identity list -c admin-peer-org2-mplescano-com@zerotoblockchain-network
composer network ping --card admin-peer-org2-mplescano-com@zerotoblockchain-network

if [[ ! -z "${temp_http_proxy}" ]]; then
   http_proxy=$temp_http_proxy
   https_proxy=$temp_https_proxy
   no_proxy=$temp_no_proxy
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
