#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
set -e

if [ ! -f /data/logs/$FABRIC_CA_SERVER_CSR_CN.success ]; then
# Initialize the root CA
mkdir $FABRIC_CA_SERVER_HOME
#cp -f /scripts/fabric-ca-server-config.yaml.template $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
#IFS='' (or IFS=) prevents leading/trailing whitespace from being trimmed.
#-r prevents backslash escapes from being interpreted.
#|| [[ -n $line ]] prevents the last line from being ignored if it doesn't end with a \n (since read returns a non-zero exit code when it encounters EOF).
#ARR_USER_PASS=$(echo $BOOTSTRAP_USER_PASS | tr ":" "\n")
IFS=':' read -ra ARR_USER_PASS <<< "$BOOTSTRAP_USER_PASS"
{
CA_ADMIN=${ARR_USER_PASS[0]}
CA_PASS=${ARR_USER_PASS[1]}
#see https://stackoverflow.com/a/46716887/3434748
while IFS='' read -r line || [[ -n "$line" ]]; do
    line=${line//\\/\\\\}         # escape backslashes
    line=${line//\"/\\\"}         # escape "
    line=${line//\`/\\\`}         # escape `
    line=${line//\$/\\\$}         # escape $
    line=${line//\\\${/\${}       # de-escape ${
    eval "echo \"$line\""
done < "/scripts/fabric-ca-server-config.yaml.template"

} > $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

# Add the custom orgs
#echo "FABRIC_ORGS:${FABRIC_ORGS}"
for o in $FABRIC_ORGS; do
   aff=$aff"\n   $o: []"
#   echo "aff:${aff}"
done
aff="${aff#\\n   }"
sed -i "/affiliations:/a \\   $aff" \
   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

fabric-ca-server init -b $BOOTSTRAP_USER_PASS

# Copy the root CA's signing certificate to the data directory to be used by others
cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $TARGET_CERTFILE

cp -f $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml /data/logs/fabric-ca-server-config-$CURRENT_ORG.yaml

touch /data/logs/$FABRIC_CA_SERVER_CSR_CN.success
fi

# Start the root CA
fabric-ca-server start

