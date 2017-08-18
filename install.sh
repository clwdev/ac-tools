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

curl -sso ac-crawl https://raw.githubusercontent.com/clwdev/ac-tools/master/ac-crawl/ac-crawl.sh
chmod 0755 ac-crawl

curl -sso ac-db https://raw.githubusercontent.com/clwdev/ac-tools/master/ac-db/ac-db.sh
chmod 0755 ac-db

echo "Installation complete"
cd - >/dev/null 2>&1
