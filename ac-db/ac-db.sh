#!/bin/bash
# Pulls the latest db backup from Acquia

if [ "$1" = "" ] || [ "$2" = "" ]
then
  echo "Pulls the latest db backup from Acquia"
  echo "Usage:    $0 <site-alias> <site-environment>"
  echo "Example:  $0 foo dev"
  exit 1
fi

remote_site="$1"
remote_env="$2"
drush_alias=$site'.'$remote_env

# getlatestbackupid, from the monolithic ac-update
id=""
attempt=1
while [[ $id = "" ]] || [[ $id = "null" ]]
do
  echo "Asking Acquia for a list of backups for @$remote_site.$remote_env. One moment..."
  json="$(drush @$remote_site.$remote_env ac-database-instance-backup-list $remote_site --format=json)"
  if [[ $json == *"Not authorized"* ]]
  then
    echo -e "${RED}ERROR:${NC} You do not have authority to get a backup."
    echo "Note: This assumes your remote site uses a database named $remote_site."
    echo "Let's make sure we are logged in to the correct Acquia account."
    drush @$remote_site.$remote_env ac-api-login
  fi
  id=$( php -r "\$backups = json_decode('$json'); if (isset(end(\$backups)->id)) echo end(\$backups)->id;" )
  if [[ $id = "" ]] || [[ $id = "null" ]]
  then
    echo "  Attempt $attempt failed."
    echo "  Sometimes this API call fails, so we will retry in a few seconds..."
    attempt=$(($attempt + 1))
    sleep 5
  fi
done
echo "  Backup found: $id"

file="$remote_site-$remote_env-$id.sql.gz"
if [ ! -f $file ]; then
  echo "Downloading backup..."
  drush @$remote_site.$remote_env ac-database-instance-backup-download $remote_site $id --result-file="$file"
else
  echo "You've already downloaded the latest backup"
fi

echo "Done!"