#!/bin/bash
# Install ac-tools via curl

echo "Installing/updating ac-tools"
cd /usr/local/bin

curl -o ac-logs https://raw.githubusercontent.com/clwdev/ac-tools/master/ac-logs/ac-logs.sh
curl -o ac-quiet https://raw.githubusercontent.com/clwdev/ac-tools/master/ac-quiet/ac-quiet.sh
curl -o ac-update https://raw.githubusercontent.com/clwdev/ac-tools/master/ac-update/ac-update.sh

echo "Installation complete"
cd -
