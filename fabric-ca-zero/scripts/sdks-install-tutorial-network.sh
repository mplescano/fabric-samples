#!/bin/bash

set -e

mkdir $HOME/developer || true
cd $HOME/developer || true
#rm -f $HOME/developer/tutorial-network.tar.gz
rm -Rf $HOME/developer/tutorial-network
cp -rf /stuff/tutorial-network $HOME/developer
cp -f /stuff/node_modules.tar.gz $HOME/developer/tutorial-network
cd $HOME/developer/tutorial-network
gunzip < node_modules.tar.gz | tar -xv
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
composer network install --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --archiveFile tutorial-network@0.0.1.bna
composer network start --networkName tutorial-network --networkVersion 0.0.1 --networkAdmin admin-peer-org2-mplescano-com --networkAdminEnrollSecret admin-peer-org2-mplescano-compw --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --file ~/tutorial-network-networkadmin.card
#A temporary work around is to ACTIVATE the card yourself
#see https://stackoverflow.com/questions/46201984/hyperledger-composer-error-the-current-identity-must-be-activated-activation
composer card import --file ~/tutorial-network-networkadmin.card
composer identity list -c admin-peer-org2-mplescano-com@tutorial-network
composer network ping --card admin-peer-org2-mplescano-com@tutorial-network

if [[ ! -z "${temp_http_proxy}" ]]; then
   http_proxy=$temp_http_proxy
   https_proxy=$temp_https_proxy
   no_proxy=$temp_no_proxy
fi
