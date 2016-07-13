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
    terminal-notifier -message "$1" -title "Acquia Tasks Complete" -appIcon https://i.imgur.com/hlrUNId.png -sender ac-quiet.sh -sound Pop
  fi
}

site="$1"
oldlogs=""
newlogs=" "
firstrun="1"
while [[ ! -z $newlogs || $? != 0 ]]
do
  if [[ $firstrun = "1" ]]
  then
    printf "Waiting for all prior tasks to complete on '$site'."
    firstrun="0"
  else
    printf "."
    # Checking consumes resources, so wait for a few seconds between checks.
    sleep 5
  fi
  newlogs="$(drush @$site.dev ac-task-list --state=started 2>&1)"
  if [[ $newlogs != $oldlogs ]]
  then
    logdiff=${newlogs//"$oldlogs"/}
    logdiff=${logdiff//"\n"/}
    if [[ $logdiff != "" ]]
    then
      printf "\n$newlogs"
    fi
  fi
  oldlogs="$newlogs"
done
printf "\nAcquia Environment '$site' is now quiet.\n"
note "Acquia Environment '$site' is now quiet."
