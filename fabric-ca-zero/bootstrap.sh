#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# current version of fabric-ca released
export CA_TAG=${1:-1.2.0}

dockerCaPull() {
      echo "==> FABRIC CA IMAGE"
      echo
      for image in "" "-tools" "-orderer" "-peer"; do
         docker pull hyperledger/fabric-ca${image}:$CA_TAG
         docker tag hyperledger/fabric-ca${image}:$CA_TAG hyperledger/fabric-ca${image}
      done
}

echo "===> Pulling fabric ca Image"
dockerCaPull ${CA_TAG}
docker pull mplescano/hyperledger-setup-sdks
docker pull hyperledger/fabric-baseos:amd64-0.4.10
docker tag hyperledger/fabric-baseos:amd64-0.4.10 hyperledger/fabric-baseos
docker pull hyperledger/fabric-baseimage:amd64-0.4.10
docker tag hyperledger/fabric-baseimage:amd64-0.4.10 hyperledger/fabric-baseimage
if [[ ! -z "${http_proxy}" ]]; then
  docker build --build-arg http_proxy=$http_proxy --build-arg https_proxy=$https_proxy --build-arg no_proxy=$no_proxy -f ./dockerfiles/DockerfileProxiedBaseimage -t mplescano/fabric-proxied-baseimage:amd64-0.4.10 .
fi

#docker build 

echo "===> List out hyperledger docker images"
docker images | grep fabric
