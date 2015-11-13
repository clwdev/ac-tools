#!/bin/bash
# Usage: ac-quiet sitegroup-name
# Alternatively: ac-quiet sitegroup-name > /dev/null & (to background it)
function note
{
  notifier_installed=$(which terminal-notifier);
  if [ "$notifier_installed" = "" ]
  then
    brew install terminal-notifier >/dev/null 2>&1
  fi
  notifier_installed=$(which terminal-notifier);
  if [ "$notifier_installed" != "" ]
  then
    terminal-notifier -message "$1" -title "Acquia Tasks Complete" -appIcon http://i.imgur.com/hlrUNId.png -sender ac-quiet.sh -sound Pop
  fi
}

site="$1"

oldlogs=""
newlogs="$(drush @$site.dev ac-task-list --state=started)"
if [[ $newlogs != '' ]]
then
  echo "Waiting for all prior tasks to complete:"
  while [[ $newlogs != '' ]]
  do
    # Checking consumes resources, so wait for 5 seconds between checks.
    sleep 5
    newlogs="$(drush @$site.dev ac-task-list --state=started)"
    if [[ $newlogs != $oldlogs ]]
    then
      logdiff=${newlogs//"$oldlogs"/}
      logdiff=${logdiff//"\n"/}
      if [[ $logdiff != "" ]]
      then
        echo "$logdiff"
      fi
    fi
    oldlogs="$newlogs"
  done
fi
note "Acquia Environment '$site' is now quiet"