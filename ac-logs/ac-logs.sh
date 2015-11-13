#!/bin/bash
# Retrieves past and present logs for a site in Acquia Enterprise
# Put this in your /usr/local/bin folder and chmod it 0755
# Then you can search/view logs quickly from any terminal

if [ "$1" = "" ] || [ "$2" = "" ]
then
  echo "Retrieves past and present logs for a site in Acquia Enterprise"
  echo "Usage:    $0 <site-alias> <site-environment>"
  echo "Example:  $0 zeg test"
  exit 1
fi

site="$1"
remote_env="$2"
drush_alias=$site'.'$remote_env

function remotecheck
{
  echo "Checking remote."
  drush cc drush -y >/dev/null 2>&1
  drush acquia-update

  # We do not need a deep vget check here, just a minimal one
  drush @$site.$remote_env status >/dev/null 2>&1

  if [ "$?" -ne "0" ]; then
    echo -e "${RED}ERROR:${NC} You do not have permissions on @$site.$remote_env."
    echo "Or something is wrong with the remote environment."
    echo "Please update your aliases from Acquia, and make sure you can SSH to the server."
    echo "If you are receiving 401 errors, run: drush ac-api-login"
    exit 1
  else
    echo "Remote is up."
  fi
}

function livelogs
{
  logstreamloc=$(which logstream);
  if [ "$logstreamloc" = "" ];
  then
    read -p "You need the Logstream gem installed. Want to install it now? " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
      echo "Alrighty then..."
      sudo gem install logstream
    else
      exit 1
    fi
  fi

  echo
  options=("Apache Errors", "PHP Errors", "Drupal Watchdog", "Backend Errors/logs (PHP/Watchdog)", "All Errors/logs (Apache/PHP/Watchdog)", "Everything (including all requests)")
  PS3="Choose a log level: "
  select opt in "${options[@]}                " "Quit"; do
      echo
      case "$REPLY" in

      1 ) echo "Showing Apache errors only..."
        while :; do logstream tail prod:$site $remote_env --types=apache-error; sleep 1; done; exit;;
      2 ) echo "Showing PHP errors only..."
        while :; do logstream tail prod:$site $remote_env --types=php-error; sleep 1; done; exit;;
      3 ) echo "Showing Drupal Watchdog logs only..."
        while :; do logstream tail prod:$site $remote_env --types=drupal-watchdog; sleep 1; done; exit;;
      4 ) echo "Showing backend errors/watchdog logs (excluding apache errors)..."
        while :; do logstream tail prod:$site $remote_env --types=php-error drupal-watchdog; sleep 1; done; exit;;
      5 ) echo "Showing all errors/watchdog logs..."
        while :; do logstream tail prod:$site $remote_env --types=apache-error php-error drupal-watchdog; sleep 1; done; exit;;
      6 ) echo "Showing EVERYTHING..."
        while :; do logstream tail prod:$site $remote_env; sleep 1; done; exit;;

      $(( ${#options[@]}+1 )) ) echo "See ya!";
          break;;

      *) echo "Invalid option.";
          continue;;

      esac
  done
}

function pastlogs
{
  echo "Retrieving past logs for searching and aggregating." ; echo
  echo "Site: @$drush_alias"

  hostname=`drush @$drush_alias core-status "db-hostname" --format=yaml`
  hostname=${hostname/db-hostname: /}

  echo "Hostname: [$hostname]"

  tmpdir=`mktemp -d`
  cd $tmpdir
  pwd=`pwd`
  echo "Downloading logs to temporary location. This will take a minute."

  rsync -rLktIzq $drush_alias@$hostname.prod.hosting.acquia.com:/var/log/sites/$drush_alias/logs/$hostname/ "$tmpdir"

  echo "Extracting logs for quicker searching with grep."
  gunzip *.gz

  open $tmpdir

  while :
  do
    if [[ $string == '' ]]
    then
      echo "Enter a string to search for. Enter 'quit' to quit:"
      read string
    fi
    if [[ $string == 'quit' ]]
    then
      rm -rf "$tmpdir"
      echo "Done."
      exit
    else
      echo "Searching for '$string'..."
      grep -i "$string" * > aggregated.log
      if [[ -s aggregated.log ]]
      then
        echo "Opening search results."
        open aggregated.log
      else
        echo "String '$string' not found in logs."
      fi
      string=""
    fi
  done
}

options=("Search all past logs for a string", "Watch live streaming logs as they happen")
PS3="Choose an operation: "
select opt in "${options[@]} " "Quit"; do
    echo
    case "$REPLY" in

    1 ) remotecheck ; pastlogs ; exit;;
    2 ) livelogs ; exit;;

    $(( ${#options[@]}+1 )) ) echo "See ya!";
        break;;

    *) echo "Invalid option.";
        continue;;

    esac
done