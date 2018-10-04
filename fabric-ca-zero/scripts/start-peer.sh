#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

source $(dirname "$0")/env.sh

if [ ! -f /data/logs/$PEER_HOST.success ]; then
awaitSetup

# Although a peer may use the same TLS key and certificate file for both inbound and outbound TLS,
# we generate a different key and certificate for inbound and outbound TLS simply to show that it is permissible

# Generate server TLS cert and key pair for the peer
log "Generate server TLS cert and key pair for the peer $PEER_HOST with url enrollment $ENROLLMENT_URL in client home $FABRIC_CA_CLIENT_HOME, destiny folder /tmp/tls"
fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $PEER_HOST

# Copy the TLS key and cert to the appropriate place
log "Copy the TLS key and cert to the appropriate place in $PEER_HOME/tls"
TLSDIR=$PEER_HOME/tls
mkdir -p $TLSDIR
cp /tmp/tls/signcerts/* $CORE_PEER_TLS_CERT_FILE
cp /tmp/tls/keystore/* $CORE_PEER_TLS_KEY_FILE
rm -rf /tmp/tls

# Generate client TLS cert and key pair for the peer
log "Generate client TLS cert and key pair for the client peer in $CORE_PEER_TLS_CLIENTCERT_FILE $CORE_PEER_TLS_CLIENTKEY_FILE"
genClientTLSCert $PEER_NAME $CORE_PEER_TLS_CLIENTCERT_FILE $CORE_PEER_TLS_CLIENTKEY_FILE

# Generate client TLS cert and key pair for the peer CLI
log "Generate client TLS cert and key pair for the client peer CLI /$DATA/tls/$PEER_NAME-cli-client.crt /$DATA/tls/$PEER_NAME-cli-client.key"
genClientTLSCert $PEER_NAME /$DATA/tls/$PEER_NAME-cli-client.crt /$DATA/tls/$PEER_NAME-cli-client.key

# Enroll the peer to get an enrollment certificate and set up the core's local MSP directory
log "Enroll the peer to get an enrollment certificate and set up the core's local MSP directory in $CORE_PEER_MSPCONFIGPATH"
fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $CORE_PEER_MSPCONFIGPATH

log "Finish setting up the local MSP for the peer msp $CORE_PEER_MSPCONFIGPATH"
finishMSPSetup $CORE_PEER_MSPCONFIGPATH
copyAdminCert $CORE_PEER_MSPCONFIGPATH

touch /data/logs/$PEER_HOST.success
fi

# Start the peer
log "Starting peer '$CORE_PEER_ID' with MSP at '$CORE_PEER_MSPCONFIGPATH'"
env | grep CORE
PEER_LOGFILE=$LOGDIR/${PEER_NAME}.log
peer node start >> /$PEER_LOGFILE 2>&1 &
