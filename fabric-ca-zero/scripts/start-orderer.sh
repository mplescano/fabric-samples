#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

source $(dirname "$0")/env.sh

if [ ! -f /data/logs/$ORDERER_HOST.success ]; then
# Wait for setup to complete sucessfully
awaitSetup

# Enroll to get orderer's TLS cert (using the "tls" profile)
log "Enroll to get orderer's TLS cert (using the "tls" profile) for $ORDERER_HOST for URL $ENROLLMENT_URL in /tmp/tls from $FABRIC_CA_CLIENT_HOME"
fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $ORDERER_HOST

# Copy the TLS key and cert to the appropriate place
log "Copy the TLS key and cert to the appropriate place in $ORDERER_HOME/tls"
TLSDIR=$ORDERER_HOME/tls
mkdir -p $TLSDIR
cp /tmp/tls/keystore/* $ORDERER_GENERAL_TLS_PRIVATEKEY
cp /tmp/tls/signcerts/* $ORDERER_GENERAL_TLS_CERTIFICATE
rm -rf /tmp/tls

# Enroll again to get the orderer's enrollment certificate (default profile)
log "Enroll again to get the orderer's enrollment certificate (default profile) in msp $ORDERER_GENERAL_LOCALMSPDIR from $FABRIC_CA_CLIENT_HOME"
fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_GENERAL_LOCALMSPDIR

# Finish setting up the local MSP for the orderer
log "Finish setting up the local MSP for the orderer msp $ORDERER_GENERAL_LOCALMSPDIR"
finishMSPSetup $ORDERER_GENERAL_LOCALMSPDIR
copyAdminCert $ORDERER_GENERAL_LOCALMSPDIR

# Wait for the genesis block to be created
log "wait for genesis block to be created"
dowait "genesis block to be created" 60 $SETUP_LOGFILE $ORDERER_GENERAL_GENESISFILE

touch /data/logs/$ORDERER_HOST.success
fi

# Start the orderer
log "Start the orderer"
env | grep ORDERER
ORDERER_LOGFILE=$LOGDIR/${ORDERER_NAME}.log
orderer >> /$ORDERER_LOGFILE 2>&1 &
