#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

source $(dirname "$0")/env.sh

function main {

   done=false

   # Wait for setup to complete and then wait another 10 seconds for the orderer and peers to start
   awaitSetup
   sleep 10

   # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"
   logr "Using the tls of orderer: $CA_CHAINFILE"

   # Convert PEER_ORGS to an array named PORGS
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   NUM_PEER_ORGS=${#PORGS[@]}

   # Package the chaincode
   initPeerVars ${PORGS[0]} 1
   switchToUserIdentity
   packageChaincode

   # Install chaincode on the 1st peer in each org
   for ORG in $PEER_ORGS; do
      initPeerVars $ORG 1
      installChaincode
   done

   makePolicy
   if [ "$NUM_PEER_ORGS" -eq 1 ]
   then
     # Instantiate chaincode on the 1st peer of the 1st org
     initPeerVars ${PORGS[0]} 1
   else
     # Instantiate chaincode on the 1st peer of the 2nd org
     initPeerVars ${PORGS[1]} 1
   fi
   switchToAdminIdentity
   logr "Instantiating chaincode on $PEER_HOST ..."
   peer chaincode instantiate -C $CHANNEL_NAME -n $CHAINCODE_NAME -v $CHAINCODE_VERSION -c '{"Args":["init","a","100","b","200"]}' -P "$POLICY" $ORDERER_CONN_ARGS

   ## Install chaincode on 2nd peer of 2nd org
   if ! [[ "$NUM_PEER_ORGS" -eq 1 ]]
   then
    initPeerVars ${PORGS[1]} 2
    installChaincode
   fi

   done=true
}

function makePolicy  {
   POLICY="OR("
   local COUNT=0
   for ORG in $PEER_ORGS; do
      if [ $COUNT -ne 0 ]; then
         POLICY="${POLICY},"
      fi
      initOrgVars $ORG "peer"
      #possible uses are:${ORG_MSP_ID}.member or ${ORG_MSP_ID}.peer or ${ORG_MSP_ID}.admin
      POLICY="${POLICY}'${ORG_MSP_ID}.member'"
      COUNT=$((COUNT+1))
   done
   POLICY="${POLICY})"
   log "policy: $POLICY"
}

function packageChaincode {
   switchToAdminIdentity
   logr "Packaging chaincode as CHAINCODE_NAME=$CHAINCODE_NAME CHAINCODE_VERSION=$CHAINCODE_VERSION CHAINCODE_PATH=$CHAINCODE_PATH CHAINCODE_PACKAGE_PATH=$CHAINCODE_PACKAGE_PATH CHAINCODE_PACKAGE_NAME=$CHAINCODE_PACKAGE_NAME..."
   logr "Signing chaincode package from $CORE_PEER_MSPCONFIGPATH ..."
   peer chaincode package -n $CHAINCODE_NAME -v $CHAINCODE_VERSION -p $CHAINCODE_PATH -s -S $CHAINCODE_PACKAGE_PATH/$CHAINCODE_PACKAGE_NAME
}


function installChaincode {
   switchToAdminIdentity
   logr "Installing chaincode on $PEER_HOST ..."
   peer chaincode install $CHAINCODE_PACKAGE_PATH/$CHAINCODE_PACKAGE_NAME
}

function logr {
   log $*
   log $* >> $RUN_SUMPATH
}

function fatalr {
   logr "FATAL: $*"
   exit 1
}

main
