#!/bin/bash

set -e

mkdir $HOME/developer || true
cd $HOME/developer || true
rm -Rf $HOME/developer/zerotoblockchain-webapp || true
cp -rf /stuff/zerotoblockchain-webapp $HOME/developer
cp -f /stuff/node_modules.tar.gz $HOME/developer/zerotoblockchain-webapp
cd $HOME/developer/zerotoblockchain-webapp
gunzip < node_modules.tar.gz | tar -xv
rm -f node_modules.tar.gz

npm install

if [[ ! -z "${http_proxy}" ]]; then
   temp_http_proxy=$http_proxy
   temp_https_proxy=$https_proxy
   temp_no_proxy=$no_proxy
   unset http_proxy
   unset https_proxy
   unset no_proxy
fi

node enrollAdmin

node index
