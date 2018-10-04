#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

Usage() {
	echo ""
	echo "Usage: ./createPeerAdminCard.sh [-h host] [-n]"
	echo ""
	echo "Options:"
	echo -e "\t-h or --host:\t\t(Optional) name of the host to specify in the connection profile"
	echo -e "\t-n or --noimport:\t(Optional) don't import into card store"
	echo ""
	echo "Example: ./createPeerAdminCard.sh"
	echo ""
	exit 1
}

Parse_Arguments() {
	while [ $# -gt 0 ]; do
		case $1 in
			--help)
				HELPINFO=true
				;;
			--host | -h)
                shift
				HOST="$1"
				;;
            --noimport | -n)
				NOIMPORT=true
				;;
		esac
		shift
	done
}

conn_profile_composer=$HOME/conn-profile-composer.json
conn_profile_composer_yaml=$HOME/conn-profile-composer.yaml
Parse_Arguments $@

if [ "${HELPINFO}" == "true" ]; then
    Usage
fi

# Grab the current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z "${HL_COMPOSER_CLI}" ]; then
  HL_COMPOSER_CLI=$(which composer)
fi

echo
# check that the composer command exists at a version >v0.16
COMPOSER_VERSION=$("${HL_COMPOSER_CLI}" --version 2>/dev/null)
COMPOSER_RC=$?
#echo $COMPOSER_RC
if [ $COMPOSER_RC -eq 0 ]; then
    AWKRET=$(echo $COMPOSER_VERSION | awk -F. '{if ($2<20) print "1"; else print "0";}')
    if [ $AWKRET -eq 1 ]; then
        echo Cannot use $COMPOSER_VERSION version of composer with fabric 1.2, v0.20 or higher is required
        exit 1
    else
        echo Using composer-cli at $COMPOSER_VERSION
    fi
else
    echo 'No version of composer-cli has been detected, you need to install composer-cli at v0.20 or higher'
    exit 1
fi

PEER_COMPOSER_HOME=$HOME/peercomposer/org2.mplescano.com/admin
CAS_COMPOSER_HOME=$HOME/cacertscomposer/admin
#private_key_filename=""
#cert_filename=""
#CERT_PATH=""
#PRIVATE_KEY_PATH=""

PRIVATE_KEY_PATH="/data/orgs/org2.mplescano.com/peer/admin/msp/keystore/"$(ls /data/orgs/org2.mplescano.com/peer/admin/msp/keystore)
private_key_filename=$(basename $PRIVATE_KEY_PATH)

CERT_PATH="/data/orgs/org2.mplescano.com/peer/admin/msp/admincerts/"$(ls /data/orgs/org2.mplescano.com/peer/admin/msp/admincerts)
cert_filename=$(basename $CERT_PATH)

#for f in $PEER_COMPOSER_HOME/msp/keystore/*_sk; do
#  private_key_filename=$(basename $f)
#  PRIVATE_KEY_PATH=$f
#done
#for f in $PEER_COMPOSER_HOME/msp/signcerts/*.pem; do
#  cert_filename=$(basename $f)
#  CERT_PATH=$f
#done

{
private_key_path_filename=$PRIVATE_KEY_PATH
cert_path_filename=$CERT_PATH
#see https://stackoverflow.com/a/46716887/3434748
while IFS='' read -r line || [[ -n "$line" ]]; do
    line=${line//\\/\\\\}         # escape backslashes
    line=${line//\"/\\\"}         # escape "
    line=${line//\`/\\\`}         # escape `
    line=${line//\$/\\\$}         # escape $
    line=${line//\\\${/\${}       # de-escape ${
    eval "echo \"$line\""
done < "/data/conn-profile-composer.json.template"

} > $conn_profile_composer

{
#see https://stackoverflow.com/a/46716887/3434748
while IFS='' read -r line || [[ -n "$line" ]]; do
    line=${line//\\/\\\\}         # escape backslashes
    line=${line//\"/\\\"}         # escape "
    line=${line//\`/\\\`}         # escape `
    line=${line//\$/\\\$}         # escape $
    line=${line//\\\${/\${}       # de-escape ${
    eval "echo \"$line\""
done < "/data/conn-profile-composer.yaml.template"

} > $conn_profile_composer_yaml

if [ "${NOIMPORT}" != "true" ]; then
    CARDOUTPUT=/tmp/PeerAdmin@hlfv1.card
else
    CARDOUTPUT=~/fabric-dev-servers/PeerAdmin@hlfv1.card
fi

# "${HL_COMPOSER_CLI}" card create -p                      "$conn_profile_composer" -u     PeerAdmin                                                      -c          "${CERT_PATH}" -k "${PRIVATE_KEY_PATH}" -r PeerAdmin -r ChannelAdmin --file $CARDOUTPUT
"${HL_COMPOSER_CLI}" card create --connectionProfileFile "$conn_profile_composer" --user "admin-peer-org2-mplescano-com" --enrollSecret "admin-peer-org2-mplescano-compw" --role PeerAdmin --role ChannelAdmin --file $CARDOUTPUT -c "${CERT_PATH}" -k "${PRIVATE_KEY_PATH}"

if [ "${NOIMPORT}" != "true" ]; then
    if "${HL_COMPOSER_CLI}"  card list -c PeerAdmin@hlfv1 > /dev/null; then
        "${HL_COMPOSER_CLI}"  card delete -c PeerAdmin@hlfv1
    fi

    "${HL_COMPOSER_CLI}"  card import --file /tmp/PeerAdmin@hlfv1.card 
    "${HL_COMPOSER_CLI}"  card list
    echo "Hyperledger Composer PeerAdmin card has been imported, host of fabric specified as '${HOST}'"
    rm /tmp/PeerAdmin@hlfv1.card
else
    echo "Hyperledger Composer PeerAdmin card has been created, host of fabric specified as '${HOST}'"
fi
