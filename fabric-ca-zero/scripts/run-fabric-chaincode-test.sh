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

   # Convert PEER_ORGS to an array named PORGS
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   NUM_PEER_ORGS=${#PORGS[@]}

   # Query chaincode from the 1st peer of the 1st org
   initPeerVars ${PORGS[0]} 1
   switchToUserIdentity
   chaincodeQuery 100

   # Invoke chaincode on the 1st peer of the 1st org
   initPeerVars ${PORGS[0]} 1
   switchToUserIdentity
   logr "Sending invoke transaction to $PEER_HOST ..."
   peer chaincode invoke -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS

   if [ "$NUM_PEER_ORGS" -eq 1 ]
   then
     # Query chaincode on 1st peer of 1st org
     sleep 10
     initPeerVars ${PORGS[0]} 1
   else
     # Query chaincode on 2nd peer of 2nd org
     sleep 10
     initPeerVars ${PORGS[1]} 2
   fi
   switchToUserIdentity
   chaincodeQuery 90

   initPeerVars ${PORGS[0]} 1
   switchToUserIdentity

   # Revoke the user and generate CRL using admin's credentials
   revokeFabricUserAndGenerateCRL

   # Fetch config block
   fetchConfigBlock

   # Create config update envelope with CRL and update the config block of the channel
   createConfigUpdatePayloadWithCRL
   updateConfigBlock

   # querying the chaincode should fail as the user is revoked
   switchToUserIdentity
   queryAsRevokedUser
   if [ "$?" -ne 0 ]; then
      logr "The revoked user $USER_NAME should have failed to query the chaincode in the channel '$CHANNEL_NAME'"
      exit 1
   fi
   logr "Congratulations! The tests ran successfully."

   done=true
}

function chaincodeQuery {
   if [ $# -ne 1 ]; then
      fatalr "Usage: chaincodeQuery <expected-value>"
   fi
   set +e
   logr "Querying chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_HOST' ..."
   local rc=1
   local starttime=$(date +%s)
   # Continue to poll until we get a successful response or reach QUERY_TIMEOUT
   while test "$(($(date +%s)-starttime))" -lt "$QUERY_TIMEOUT"; do
      sleep 1
      peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >& log.txt
      VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
      if [ $? -eq 0 -a "$VALUE" = "$1" ]; then
         logr "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
         set -e
         return 0
      else
         # removed the string "Query Result" from peer chaincode query command result, as a result, have to support both options until the change is merged.
         VALUE=$(cat log.txt | egrep '^[0-9]+$')
         if [ $? -eq 0 -a "$VALUE" = "$1" ]; then
            logr "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
            set -e
            return 0
         fi
      fi
      echo -n "."
   done
   cat log.txt
   cat log.txt >> $RUN_SUMFILE
   fatalr "Failed to query channel '$CHANNEL_NAME' on peer '$PEER_HOST'; expected value was $1 and found $VALUE"
}

function queryAsRevokedUser {
   set +e
   logr "Querying the chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_HOST' as revoked user '$USER_NAME' ..."
   local starttime=$(date +%s)
   # Continue to poll until we get an expected response or reach QUERY_TIMEOUT
   while test "$(($(date +%s)-starttime))" -lt "$QUERY_TIMEOUT"; do
      sleep 1
      peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >& log.txt
      if [ $? -ne 0 ]; then
        err=$(cat log.txt | grep "access denied")
        if [ "$err" != "" ]; then
           logr "Expected error occurred when the revoked user '$USER_NAME' queried the chaincode in the channel '$CHANNEL_NAME'"
           set -e
           return 0
        fi
      fi
      echo -n "."
   done
   set -e 
   cat log.txt
   cat log.txt >> $RUN_SUMFILE
   return 1
}

function fetchConfigBlock {
   logr "Fetching the configuration block of the channel '$CHANNEL_NAME'"
   peer channel fetch config $CONFIG_BLOCK_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function updateConfigBlock {
   logr "Updating the configuration block of the channel '$CHANNEL_NAME'"
   peer channel update -f $CONFIG_UPDATE_ENVELOPE_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function createConfigUpdatePayloadWithCRL {
   logr "Creating config update payload with the generated CRL for the organization '$ORG'"
   # Start the configtxlator
   configtxlator start &
   configtxlator_pid=$!
   log "configtxlator_pid:$configtxlator_pid"
   logr "Sleeping 5 seconds for configtxlator to start..."
   sleep 5

   pushd /tmp

   CTLURL=http://127.0.0.1:7059
   # Convert the config block protobuf to JSON
   curl -X POST --data-binary @$CONFIG_BLOCK_FILE $CTLURL/protolator/decode/common.Block > config_block.json
   # Extract the config from the config block
   jq .data.data[0].payload.data.config config_block.json > config.json

   # Update crl in the config json
   CRL=$(cat $CORE_PEER_MSPCONFIGPATH/crls/crl*.pem | base64 | tr -d '\n')
   cat config.json | jq --arg org "$ORG" --arg crl "$CRL" '.channel_group.groups.Application.groups[$org].values.MSP.value.config.revocation_list = [$crl]' > updated_config.json

   # Create the config diff protobuf
   curl -X POST --data-binary @config.json $CTLURL/protolator/encode/common.Config > config.pb
   curl -X POST --data-binary @updated_config.json $CTLURL/protolator/encode/common.Config > updated_config.pb
   curl -X POST -F original=@config.pb -F updated=@updated_config.pb $CTLURL/configtxlator/compute/update-from-configs -F channel=$CHANNEL_NAME > config_update.pb

   # Convert the config diff protobuf to JSON
   curl -X POST --data-binary @config_update.pb $CTLURL/protolator/decode/common.ConfigUpdate > config_update.json

   # Create envelope protobuf container config diff to be used in the "peer channel update" command to update the channel configuration block
   echo '{"payload":{"header":{"channel_header":{"channel_id":"'"${CHANNEL_NAME}"'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' > config_update_as_envelope.json
   curl -X POST --data-binary @config_update_as_envelope.json $CTLURL/protolator/encode/common.Envelope > $CONFIG_UPDATE_ENVELOPE_FILE

   # Stop configtxlator
   kill $configtxlator_pid

   popd
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
