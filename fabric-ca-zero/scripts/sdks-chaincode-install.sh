#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

LOGDIR=$HOME/logs
mkdir $LOGDIR || true
# The run container's summary log file
RUN_SUMFILE=${LOGDIR}/run-sdk-install-chaincode.sum
RUN_SUMPATH=${RUN_SUMFILE}
touch $RUN_SUMPATH
export GOPATH=/opt/gopath
CHANNEL_NAME=mychannel
#export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=net_ext_fabric-ca-zero
#export CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer1.org2.mplescano.com:7051

function main {

   done=false

   # Wait for setup to complete and then wait another 10 seconds for the orderer and peers to start
   #awaitSetup
   #sleep 10

   # Names of the orderer organizations
   ORDERER_ORGS="org1.mplescano.com"
   # Names of the peer organizations
   PEER_ORGS="org2.mplescano.com"

   # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1 "admin"
   export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $CA_CHAINFILE --clientauth"

   # Convert PEER_ORGS to an array named PORGS
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   NUM_PEER_ORGS=${#PORGS[@]}

   # Install chaincode on the 1st peer in each org
   for ORG in $PEER_ORGS; do
      initPeerVars $ORG 1 "admin"
      installChaincode
   done

   makePolicy
   if [ "$NUM_PEER_ORGS" -eq 1 ]
   then
     # Instantiate chaincode on the 1st peer of the 1st org
     initPeerVars ${PORGS[0]} 1 "admin"
   else
     # Instantiate chaincode on the 1st peer of the 2nd org
     initPeerVars ${PORGS[1]} 1 "admin"
   fi
   switchToAdminIdentity
   logr "Instantiating chaincode on $PEER_HOST ..."
#   logr `printenv`
   peer chaincode instantiate -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "$POLICY" $ORDERER_CONN_ARGS

   ## Install chaincode on 2nd peer of 2nd org
#   if ! [[ "$NUM_PEER_ORGS" -eq 1 ]]
#   then
#    initPeerVars ${PORGS[1]} 2
#    installChaincode
#   fi

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
      POLICY="${POLICY}'${ORG_MSP_ID}.member'"
      COUNT=$((COUNT+1))
   done
   POLICY="${POLICY})"
   log "policy: $POLICY"
}

function installChaincode {
   switchToAdminIdentity
   logr "Installing chaincode on $PEER_HOST ..."
   logr `printenv`
   peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/abac/go
}

function logr {
   log $*
   log $* >> $RUN_SUMPATH
}

function fatalr {
   logr "FATAL: $*"
   exit 1
}


function initOrgVars {
   if [ $# -ne 2 ]; then
      echo "Usage: initOrgVars <ORG>"
      exit 1
   fi
   ORG=$1
   ROL=$2
   ORG_CONTAINER_NAME=${ORG//./-}
   ORG_MSP_ID=${ROL}${ORG}MSP
   ROOT_CA_NAME=rca-${ORG_CONTAINER_NAME}
   CA_NAME=$ROOT_CA_NAME

   ADMIN_NAME=admin-${ROL}-${ORG_CONTAINER_NAME}
   USER_NAME=user-${ROL}-${ORG_CONTAINER_NAME}
   ANCHOR_TX_FILE=/data/orgs/${ORG}/anchors.tx
}

function initOrdererVars {
   if [ $# -ne 3 ]; then
      echo "Usage: initOrdererVars <ORG> <NUM> <TYPE>: $*"
      exit 1
   fi
   initOrgVars $1 "ord"
   NUM=$2
   USER_TYPE=$3
   ROOT_CA_CERTFILE=${HOME}/cacertscomposer/$USER_TYPE/msp/cacerts/$CA_NAME-7054.pem
   CA_CHAINFILE=$ROOT_CA_CERTFILE
   ORDERER_HOST=orderer${NUM}.${ORG}
   # enabled TLS
#   export ORDERER_GENERAL_TLS_ENABLED=true
   #export ORDERER_GENERAL_TLS_PRIVATEKEY=${HOME}/orderercomposer/$ORG/$USER_TYPE/tls/cli-client.key
   #export ORDERER_GENERAL_TLS_CERTIFICATE=$TLSDIR/server.crt
#   export ORDERER_GENERAL_TLS_ROOTCAS=[$CA_CHAINFILE]
#   export ORDERER_GENERAL_LOCALMSPID=$ORG_MSP_ID
#   export ORDERER_GENERAL_LOCALMSPDIR=${HOME}/orderercomposer/$ORG/$USER_TYPE/msp
}

function initPeerVars {
   if [ $# -ne 3 ]; then
      echo "Usage: initPeerVars <ORG> <NUM> <TYPE>: $*"
      exit 1
   fi
   initOrgVars $1 "peer"
   NUM=$2
   USER_TYPE=$3
   PEER_HOST=peer${NUM}.${ORG}
   HOST_PEER_NAME=$HOSTNAME-peer-${ORG_CONTAINER_NAME}

   ROOT_CA_CERTFILE=${HOME}/cacertscomposer/$USER_TYPE/msp/cacerts/$CA_NAME-7054.pem
   CA_CHAINFILE=$ROOT_CA_CERTFILE

   export FABRIC_CFG_PATH=$HOME/peercomposer
   touch $FABRIC_CFG_PATH/core.yaml
   export CORE_PEER_ID="sdk-cli"
   export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
   export CORE_PEER_TLS_ENABLED=true
   export CORE_PEER_TLS_CLIENTCERT_FILE=${HOME}/peercomposer/$ORG/$USER_TYPE/tls/cli-client.crt
   export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
   export CORE_PEER_TLS_CLIENTKEY_FILE=${HOME}/peercomposer/$ORG/$USER_TYPE/tls/cli-client.key
   export CORE_PEER_ADDRESS=$PEER_HOST:7051
   export CORE_PEER_LOCALMSPID=$ORG_MSP_ID
   export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
}

function switchToAdminIdentity {
   log "Swithing to admin identity $ADMIN_NAME"
   log "Previous folder identity: $CORE_PEER_MSPCONFIGPATH"
   export FABRIC_CA_CLIENT_HOME=$HOME/cacertscomposer/admin/$CA_NAME
   export CORE_PEER_MSPCONFIGPATH=/data/orgs/$ORG/peer/admin/msp
   log "Current folder identity: $CORE_PEER_MSPCONFIGPATH"
}

# Switch to the current org's user identity.  Enroll if not previously enrolled.
function switchToUserIdentity {
   log "Swithing to user identity $USER_NAME"
   log "Previous folder identity: $CORE_PEER_MSPCONFIGPATH"
   export FABRIC_CA_CLIENT_HOME=$HOME/cacertscomposer/user/$CA_NAME
   export CORE_PEER_MSPCONFIGPATH=/data/orgs/$ORG/peer/msp
   log "Current folder identity: $CORE_PEER_MSPCONFIGPATH"
}

# log a message
function log {
   if [ "$1" = "-n" ]; then
      shift
      echo -n "##### `date '+%Y-%m-%d %H:%M:%S'` $*"
   else
      echo "##### `date '+%Y-%m-%d %H:%M:%S'` $*"
   fi
}


main
