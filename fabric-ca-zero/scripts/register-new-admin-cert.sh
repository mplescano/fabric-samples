#!/bin/bash

set -e

if [ $# -ne 2 ]; then
   echo "Usage: command <file-path-cert-peer> <file-path-cert-orderer>"
   exit 1
fi
if [ ! -f $1 ]; then
   echo "File $1 does not exist."
   exit 1
fi
if [ ! -f $2 ]; then
   echo "File $2 does not exist."
   exit 1
fi
ADMIN_CERT_PEER_FILE_PATH=$1
ADMIN_CERT_ORDERER_FILE_PATH=$2

docker cp $ADMIN_CERT_PEER_FILE_PATH peer1-org2-mplescano-com:/opt/gopath/src/github.com/hyperledger/fabric/peer/msp/admincerts/
docker cp $ADMIN_CERT_PEER_FILE_PATH peer2-org2-mplescano-com:/opt/gopath/src/github.com/hyperledger/fabric/peer/msp/admincerts/
docker cp $ADMIN_CERT_ORDERER_FILE_PATH orderer1-org1-mplescano-com:/etc/hyperledger/orderer/msp/admincerts/

#PID_PEER1=$(docker exec -it peer1-org2-mplescano-com pidof peer)
#PID_PEER2=$(docker exec -it peer2-org2-mplescano-com pidof peer)
#PID_ORDERER1=$(docker exec -it orderer1-org1-mplescano-com pidof orderer)

#echo ${PID_PEER1}
#echo ${PID_PEER2}
#echo ${PID_ORDERER1}

docker exec -d peer1-org2-mplescano-com /bin/bash -c "kill -SIGTERM \$(pidof peer) && export PEER_LOGFILE=/data/logs/\${PEER_NAME}.log && peer node start >> \$PEER_LOGFILE 2>&1 &"
docker exec -d peer2-org2-mplescano-com /bin/bash -c "kill -SIGTERM \$(pidof peer) && export PEER_LOGFILE=/data/logs/\${PEER_NAME}.log && peer node start >> \$PEER_LOGFILE 2>&1 &"
docker exec -d orderer1-org1-mplescano-com /bin/bash -c "kill -SIGTERM \$(pidof orderer) && export ORDERER_LOGFILE=/data/logs/\${ORDERER_NAME}.log && orderer >> \$ORDERER_LOGFILE 2>&1 &"
