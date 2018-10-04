#!/bin/bash
#

# see https://github.com/hyperledger/composer/blob/master/packages/composer-cli/test/card/data/connection.yaml
function main {
   if [ ! -f /data/logs/setup-sdks.success ]; then
   log "Beginning sdks phase 2 installation ..."
   awaitSetup
   sleep 10

   if [[ ! -z "${http_proxy}" ]]; then
     echo "export http_proxy=$http_proxy" >> /home/user_composer/.profile
   fi
   if [[ ! -z "${https_proxy}" ]]; then
     echo "export https_proxy=$https_proxy" >> /home/user_composer/.profile
   fi
   if [[ ! -z "${no_proxy}" ]]; then
      echo "export no_proxy=$no_proxy" >> /home/user_composer/.profile
   fi

   su - user_composer -c '/scripts/sdks-setup-enroll.sh'
#   cp -f /home/user_composer/peercomposer/org2.mplescano.com/admin/msp/signcerts/cert.pem /data/admin-peer-org2-mplescano-com-user-composer.pem
#   cp -f /home/user_composer/orderercomposer/org1.mplescano.com/admin/msp/signcerts/cert.pem /data/admin-orderer-org1-mplescano-com-user-composer.pem

   makeConnProfileComposerJson
   makeConnProfileComposerYaml

   #see https://unix.stackexchange.com/questions/195466/setting-multiple-groups-as-directory-owners
   echo "user_composer ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/user_composer
   #chmod 0440 /etc/sudoers.d/user_composer
   #usermod -a -G root user_composer
   setfacl -m g:user_composer:rx -R /data/orgs
   setfacl -m g:user_composer:rx -R /stuff

   su - user_composer -c '/scripts/create-composer-peer-admin-card.sh'

   log "Finished sdks phase 2 installation"
   touch /data/logs/setup-sdks.success
   fi
}

function makeConnProfileComposerYaml {
   # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"

   # Convert PEER_ORGS to an array named PORGS
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   #choosing the firt org of the peers
   initPeerVars ${PORGS[0]} 1

   {
   echo "name: \"$PEER_ORG Client\"
x-type: \"hlfv1\"
x-commitTimeout: 300
version: \"1.0.0\"
client:
  organization: $PEER_ORG
  connection:
    timeout:
      peer:
        endorser: 300
        eventHub: 300
        eventReg: 300
      orderer: 300

channels:
  $CHANNEL_NAME:
    orderers:"
   for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         echo "
      - $ORDERER_HOST"
        COUNT=$((COUNT+1))
      done
   done

   echo "
    peers:"
   # All peers
   # only the first peer of each org is endorser by convention here :P
   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         echo "
      $PEER_HOST:
        endorsingPeer: $(if [ $COUNT -eq 1 ]; then echo 'true'; else echo 'false'; fi)
        chaincodeQuery: $(if [ $COUNT -eq 1 ]; then echo 'true'; else echo 'false'; fi)
        ledgerQuery: true
        eventSource: false"
         COUNT=$((COUNT+1))
      done
   done
   echo "
organizations:"
   #IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   #NUM_PEER_ORGS=${#PEER_ORGS[@]}
   #COUNT_PEER_ORGS=1
   #for ORG in $PEER_ORGS; do
   #  initPeerVars $ORG 1
     initPeerVars ${PORGS[0]} 1
     echo "
  $ORG:
    mspid: $ORG_MSP_ID
    peers:"
     {
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
          initPeerVars $ORG $COUNT
          echo "
      - $PEER_HOST"
          COUNT=$((COUNT+1))
        done
     }
     echo "
    certificateAuthorities:
      - $CA_HOST
    adminPrivateKey:
      path: \"\${PEER_COMPOSER_HOME}/msp/keystore/\${private_key_filename}\"
    signedCert:
      path: \"\${PEER_COMPOSER_HOME}/msp/signcerts/\${cert_filename}\""
   #done

   echo "
orderers:"
   # Orderes can have diferent CAs
   for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         echo "
  $ORDERER_HOST:
    url: grpcs://$ORDERER_HOST:7050
    tlsCACerts:
      path: \"\${PEER_COMPOSER_HOME}/msp/cacerts/$CA_NAME-7054.pem\""
         COUNT=$((COUNT+1))
      done
   done

   echo "
peers:"
   # All peers
   #COUNT_PEER_ORGS=1
   #for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         #initPeerVars $ORG $COUNT
         initPeerVars ${PORGS[0]} $COUNT
         echo "
  $PEER_HOST:
    url: grpcs://$PEER_HOST:7051
    tlsCACerts:
      path: \"\${PEER_COMPOSER_HOME}/msp/cacerts/$CA_NAME-7054.pem\""
         COUNT=$((COUNT+1))
      done
   #  COUNT_PEER_ORGS=$((COUNT_PEER_ORGS+1))
   #done

   echo "
certificateAuthorities:"
   #COUNT_PEER_ORGS=1
   #for ORG in $PEER_ORGS; do
   #  initPeerVars $ORG 1
     initPeerVars ${PORGS[0]} 1
     echo "
  $CA_HOST:
    url: https://$CA_HOST:7054
    caName: $CA_NAME
    httpOptions:
      verify: false
    tlsCACerts:
      path: \"\${PEER_COMPOSER_HOME}/msp/cacerts/$CA_NAME-7054.pem\""
   #  COUNT_PEER_ORGS=$((COUNT_PEER_ORGS+1))
   #done

  } > /$DATA/conn-profile-composer.yaml.template
}

#In channels specifies all the peers and orderer for all the orgs
#but in $.organizations  and $.peers only specifies the peer of the org that you want to connect
function makeConnProfileComposerJson {
   # Set ORDERER_PORT_ARGS to the args needed to communicate with the 1st orderer
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   NUM_ALL_OORGS=${#OORGS[@]}

   # Convert PEER_ORGS to an array named PORGS
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   NUM_ALL_PORGS=${#PORGS[@]}

   # Convert PEER_ORGS to an array named PORGS
   IFS=', ' read -r -a AORGS <<< "$ORGS"
   NUM_ALL_ORGS=${#AORGS[@]}

   #choosing the firt org of the peers
   initPeerVars ${PORGS[0]} 1

   {
   echo "{
    \"name\": \"$PEER_ORG Client\",
    \"x-type\": \"hlfv1\",
    \"x-commitTimeout\": 300,
    \"version\": \"1.0.0\",
    \"client\": {
        \"organization\": \"$PEER_ORG\",
        \"connection\": {
            \"timeout\": {
                \"peer\": {
                    \"endorser\": \"300\",
                    \"eventHub\": \"300\",
                    \"eventReg\": \"300\"
                },
                \"orderer\": \"300\"
            }
        }
    },
    \"channels\": {
        \"$CHANNEL_NAME\": {
            \"orderers\": [
"
   for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         echo "
                 \"$ORDERER_HOST\"
"
         COUNT=$((COUNT+1))
         if [ "$COUNT" -lt $NUM_ORDERERS ]; then
            echo ","
         fi
      done
   done

   echo "
            ],
            \"peers\": {
"
   # All peers
   # only the first peer of each org is endorser by convention here :P
   # all the peers can emit events but it is up to client to choose which peer to listening. It's 
   # important to setting at least one eventsource because it impacts the Promise of composer'apis
   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         echo "
           \"$PEER_HOST\": {
                \"endorsingPeer\": $(if [ $COUNT -eq 1 ]; then echo 'true'; else echo 'false'; fi),
                \"chaincodeQuery\": $(if [ $COUNT -eq 1 ]; then echo 'true'; else echo 'false'; fi),
                \"ledgerQuery\": true,
                \"eventSource\": true
           }
"
         if [ "$COUNT" -lt $NUM_PEERS ]; then
            echo ","
         fi
         COUNT=$((COUNT+1))
      done
   done
   echo "
            }
        }
    },
"
   echo "
    \"organizations\": {"

#   if ! [[ $NUM_ALL_ORGS -eq $NUM_ALL_OORGS && $NUM_ALL_ORGS -eq $NUM_ALL_PORGS ]]; then
#     for ORG in $ORDERER_ORGS; do
#       local COUNT=1
#       echo "
#         \"$ORG\": {
#           \"mspid\": \"$ORG_MSP_ID\",
#           \"orderers\": [
#"
#       while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
#         initOrdererVars $ORG $COUNT
#         echo "
#                 \"$ORDERER_HOST\"
#"
#         COUNT=$((COUNT+1))
#         if [ "$COUNT" -lt $NUM_ORDERERS ]; then
#            echo ","
#         fi
#       done
#       echo "
#             ],"
#       echo "
#            \"certificateAuthorities\": [
#                \"$CA_HOST\"
#            ],
#            \"adminPrivateKey\": {
#              \"path\": \"\${ORDERER_COMPOSER_HOME}/msp/keystore/\${private_key_filename}\"
#            },
#            \"signedCert\": {
#              \"path\": \"\${ORDERER_COMPOSER_HOME}/msp/signcerts/\${cert_filename}\"
#            }
#"
#       echo "
#         },"
#     done
#   fi

   #IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   #NUM_PEER_ORGS=${#PEER_ORGS[@]}
   #COUNT_PEER_ORGS=1
   #for ORG in $PEER_ORGS; do
   #  initPeerVars $ORG 1
     initPeerVars ${PORGS[0]} 1
     echo "
        \"$ORG\": {
            \"mspid\": \"$ORG_MSP_ID\",
            \"peers\": [
"
     {
        local COUNT=1
        while [[ "$COUNT" -le $NUM_PEERS ]]; do
          initPeerVars $ORG $COUNT
          echo "             \"$PEER_HOST\""
          if [ "$COUNT" -lt $NUM_PEERS ]; then
             echo ","
          fi
          COUNT=$((COUNT+1))
        done
     }
     echo "
             ],"
     echo "
            \"certificateAuthorities\": [
                \"$CA_HOST\"
            ]"
     echo ",
            \"adminPrivateKey\": {
              \"path\": \"\${private_key_path_filename}\"
            },
            \"signedCert\": {
              \"path\": \"\${cert_path_filename}\"
            }
"

     echo "
         }"
   #  if [ "$COUNT_PEER_ORGS" -lt $NUM_PEER_ORGS ]; then
   #     echo ","
   #  fi
   #  COUNT_PEER_ORGS=$((COUNT_PEER_ORGS+1))
   #done

   echo "
    },"

   echo "
    \"orderers\": {
"
   # Orderes can have diferent CAs
   for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         echo "
       \"$ORDERER_HOST\": {
            \"url\": \"grpcs://$ORDERER_HOST:7050\",
            \"tlsCACerts\": {
                \"path\": \"\${CAS_COMPOSER_HOME}/msp/cacerts/$CA_NAME-7054.pem\",
                \"client\": {
                  \"keyfile\": \"\${PEER_COMPOSER_HOME}/tls/cli-client.key\",
                  \"certfile\": \"\${PEER_COMPOSER_HOME}/tls/cli-client.crt\"
                }
            }
        }
"
         if [ "$COUNT" -lt $NUM_ORDERERS ]; then
            echo ","
         fi
         COUNT=$((COUNT+1))
      done
   done

   echo "
    },
"
   echo "
    \"peers\": {
"
   # All peers
   #COUNT_PEER_ORGS=1
   #for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         #initPeerVars $ORG $COUNT
         initPeerVars ${PORGS[0]} $COUNT
         echo "
           \"$PEER_HOST\": {
              \"url\": \"grpcs://$PEER_HOST:7051\",
              \"tlsCACerts\": {
                \"path\": \"\${CAS_COMPOSER_HOME}/msp/cacerts/$CA_NAME-7054.pem\",
                \"client\": {
                  \"keyfile\": \"\${PEER_COMPOSER_HOME}/tls/cli-client.key\",
                  \"certfile\": \"\${PEER_COMPOSER_HOME}/tls/cli-client.crt\"
                }
              }
           }
"
         if [ "$COUNT" -lt $NUM_PEERS ]; then
            echo ","
         fi
         COUNT=$((COUNT+1))
      done
   #  if [ "$COUNT_PEER_ORGS" -lt $NUM_PEER_ORGS ]; then
   #     echo ","
   #  fi
   #  COUNT_PEER_ORGS=$((COUNT_PEER_ORGS+1))
   #done
   echo "
    },
"

   echo "
    \"certificateAuthorities\": {
"
   COUNT_ALL_ORGS=1
   for ORG in $ORGS; do
     initOrgVars $ORG "rca"
   #  initPeerVars ${PORGS[0]} 1
     echo "
        \"$CA_HOST\": {
            \"url\": \"https://$CA_HOST:7054\",
            \"caName\": \"$CA_NAME\",
            \"httpOptions\": {
              \"verify\": false
            },
            \"tlsCACerts\": {
              \"path\": \"\${CAS_COMPOSER_HOME}/msp/cacerts/$CA_NAME-7054.pem\"
            }
        }"
   # you could add in certificateAuthorities for "trustedRoots": Array of PEM-encoded trusted root certificates
     if [ "$COUNT_ALL_ORGS" -lt $NUM_ALL_ORGS ]; then
        echo ","
     fi
     COUNT_ALL_ORGS=$((COUNT_ALL_ORGS+1))
   done

   echo "
    }
}
"
   } > /$DATA/conn-profile-composer.json.template
}

set -e

SDIR=$(dirname "$0")
source $SDIR/env.sh

main
#makeConnProfileComposerJson
#makeConnProfileComposerYaml
