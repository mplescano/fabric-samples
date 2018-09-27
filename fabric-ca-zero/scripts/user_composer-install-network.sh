#!/bin/bash

set -e

mkdir $HOME/developer
cd $HOME/developer
cp -f /data/tutorial-network.tar.gz $HOME/developer
gunzip < tutorial-network.tar.gz | tar -xv
cd $HOME/developer/tutorial-network
composer archive create -t dir -n .
export DEBUG=composer[debug]:*,grpc[debug]:*,verbatim[debug]:*
composer network install --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --archiveFile tutorial-network@0.0.1.bna
composer network start --networkName tutorial-network --networkVersion 0.0.1 --networkAdmin admin-peer-org2-mplescano-com --networkAdminEnrollSecret admin-peer-org2-mplescano-compw --card admin-peer-org2-mplescano-com@org2mplescanocom-Client --file ~/tutorial-network-networkadmin.card
