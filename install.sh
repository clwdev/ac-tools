#!/bin/bash
# Install ac-tools via curl

echo "Installing/updating ac-tools"
cd /usr/local/bin

curl -sso ac-logs https://raw.githubusercontent.com/clwdev/ac-tools/master/ac-logs/ac-logs.sh
chmod 0755 ac-logs

curl -sso ac-quiet https://raw.githubusercontent.com/clwdev/ac-tools/master/ac-quiet/ac-quiet.sh
chmod 0755 ac-quiet

curl -sso ac-update https://raw.githubusercontent.com/clwdev/ac-tools/master/ac-update/ac-update.sh
chmod 0755 ac-update

echo "Installation complete"
cd -
