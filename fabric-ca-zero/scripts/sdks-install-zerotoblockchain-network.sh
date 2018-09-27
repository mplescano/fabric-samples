#!/bin/bash

set -e

mkdir $HOME/developer || true
cd $HOME/developer || true
cp -f /data/zerotoblockchain-network.tar.gz $HOME/developer
gunzip < zerotoblockchain-network.tar.gz | tar -xv
cd $HOME/developer/zerotoblockchain-network
rm -Rf dist/
#npm install
#composer archive create --sourceType dir --sourceName . --archiveFile ./tutorial-network.bna
composer archive create -t dir -n .
export DEBUG=composer[debug]:*,grpc[debug]:*,verbatim[debug]:*
composer network install --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --archiveFile zerotoblockchain-network@0.1.5.bna
composer network start --networkName zerotoblockchain-network --networkVersion 0.0.1 --networkAdmin admin-peer-org2-mplescano-com --networkAdminEnrollSecret admin-peer-org2-mplescano-compw --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --file ~/zerotoblockchain-network-networkadmin.card
#A temporary work around is to ACTIVATE the card yourself
#see https://stackoverflow.com/questions/46201984/hyperledger-composer-error-the-current-identity-must-be-activated-activation
composer identity list -c admin-peer-org2-mplescano-com@zerotoblockchain-network
composer network ping --card admin-peer-org2-mplescano-com@zerotoblockchain-network
