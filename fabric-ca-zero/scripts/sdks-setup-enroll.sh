#!/bin/bash

function main {
  log "Beginning enroll ..."
  # Convert PEER_ORGS to an array named PORGS
  IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
  IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"

  #the 1st peer of the 1st org
  export PEER_HOME=$HOME/peercomposer/${PORGS[0]}
  #the 1st orderer of the 1st org
  export ORDERER_HOME=$HOME/orderercomposer/${OORGS[0]}
  export CACERTS_HOME=$HOME/cacertscomposer
  for USER_TYPE in "admin" "user"; do
    #the 1st orderer of the 1st org
    initOrdererVars ${OORGS[0]} 1
    export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
    export FABRIC_CA_CLIENT_HOME=$CACERTS_HOME/$USER_TYPE/$CA_NAME
    log "Getting CA certs for organization $ORG, rol ord and storing in $MSPCONFIGPATH"
    fabric-ca-client getcacert -d -u https://$CA_HOST:7054 -M $CACERTS_HOME/$USER_TYPE/msp
    finishMSPSetup $CACERTS_HOME/$USER_TYPE/msp
    export MSPCONFIGPATH=$ORDERER_HOME/$USER_TYPE/msp
    mkdir -p $MSPCONFIGPATH
    if [ "$USER_TYPE" = "admin" ]; then
      TLS_USER_NAME=$ADMIN_NAME
      ENROLLMENT_URL=https://$ADMIN_NAME:$ADMIN_PASS@$CA_HOST:7054
      # Generate client TLS cert and key pair for the peer CLI
      log "Generate client TLS cert and key pair for the client peer CLI $PEER_HOME/$USER_TYPE/tls/"
      mkdir -p $ORDERER_HOME/$USER_TYPE/tls
      genClientTLSCert $TLS_USER_NAME $ORDERER_HOME/$USER_TYPE/tls/cli-client.crt $ORDERER_HOME/$USER_TYPE/tls/cli-client.key
      # Enroll the peer to get an enrollment certificate and set up the core's local MSP directory
      #log "Enroll the peer to get an enrollment certificate and set up the core's local MSP directory in $MSPCONFIGPATH"
      #fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $MSPCONFIGPATH
      #log "Finish setting up the local MSP for the peer msp $CORE_PEER_MSPCONFIGPATH"
      #finishMSPSetup $MSPCONFIGPATH
      #mkdir $MSPCONFIGPATH/admincerts
      #cp $MSPCONFIGPATH/signcerts/* $MSPCONFIGPATH/admincerts/cert.pem
    fi

    #the 1st peer of the 1st org
    initPeerVars ${PORGS[0]} 1
    export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
    export FABRIC_CA_CLIENT_HOME=$CACERTS_HOME/$USER_TYPE/$CA_NAME
    if [ "${OORGS[0]}" != "${PORGS[0]}" ]; then
      log "Getting CA certs for organization $ORG, rol peer and storing in $MSPCONFIGPATH"
      fabric-ca-client getcacert -d -u https://$CA_HOST:7054 -M $CACERTS_HOME/$USER_TYPE/msp
      finishMSPSetup $CACERTS_HOME/$USER_TYPE/msp
    fi
    export MSPCONFIGPATH=$PEER_HOME/$USER_TYPE/msp
    mkdir -p $MSPCONFIGPATH
    if [ "$USER_TYPE" = "admin" ]; then
      TLS_USER_NAME=$ADMIN_NAME
      ENROLLMENT_URL=https://$ADMIN_NAME:$ADMIN_PASS@$CA_HOST:7054
    else
      TLS_USER_NAME=$USER_NAME
      ENROLLMENT_URL=https://$USER_NAME:$USER_PASS@$CA_HOST:7054
    fi
    # Generate client TLS cert and key pair for the peer CLI
    log "Generate client TLS cert and key pair for the client peer CLI $PEER_HOME/$USER_TYPE/tls/"
    mkdir -p $PEER_HOME/$USER_TYPE/tls
    genClientTLSCert $TLS_USER_NAME $PEER_HOME/$USER_TYPE/tls/cli-client.crt $PEER_HOME/$USER_TYPE/tls/cli-client.key
    # Enroll the peer to get an enrollment certificate and set up the core's local MSP directory
    #log "Enroll the peer to get an enrollment certificate and set up the core's local MSP directory in $MSPCONFIGPATH"
    #fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $MSPCONFIGPATH
    #log "Finish setting up the local MSP for the peer msp $CORE_PEER_MSPCONFIGPATH"
    #finishMSPSetup $MSPCONFIGPATH
    #mkdir $MSPCONFIGPATH/admincerts
    #cp $MSPCONFIGPATH/signcerts/* $MSPCONFIGPATH/admincerts/cert.pem

    log "Finished enrollments for $USER_TYPE"
  done
}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main
