#!/bin/bash
# Updates a local Drupal 7 environment to match a production in Acquia
# Expects a local Mac environment with Drush, Brew, and Acquia aliases installed

if [ "$1" = "" ] || [ "$2" = "" ]
then
  echo "Updates a local Drupal 7 environment to match a production in Acquia"
  echo "Expects a local Mac environment with Drush, Brew, and Acquia aliases installed"
  echo
  echo "Usage:    $0 <site-alias> <site-environment>"
  echo "Example:  $0 qrk test"
  exit 1
fi

# Search up the current directory tree, searching for a file such as a docroot's index.php
function upsearch () {
  test / == "$PWD" && return || test -e "$1" && return || cd .. && upsearch "$1"
}

# Initialize this script
remote_site="$1"
local_site="$1"
remote_env="$2"
current_time=$(date "+%Y.%m.%d-%H.%M.%S")
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
status_security="unknown"
status_fra="unknown"
upsearch "index.php"
BASEDIR="$PWD"
echo "Remote site: @$remote_site.$remote_env"
echo "Local Drupal root: $BASEDIR"
if [ ! -d "$BASEDIR""/sites/""$local_site" ]
then
  local_site="default"
  echo -e "Local site: ${YELLOW}$local_site${NC} (appears to not be multisite)"
else
  echo -e "Local site: ${GREEN}$local_site${NC}"
fi
if [[ $BASEDIR = "/" ]]
then
  echo -e "${RED}ERROR:${NC} Could not find Drupal root. Please run this from within your drupal instance."
  exit
fi
echo

# Usage: note "message" 1 (1 signifies to include a drush uli link)
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

    if [[ $2 = "1" ]]
    then
      uli_link=$( drush $local_site uli --browser=0 );
      terminal-notifier -message "$1" -title "Domino" -appIcon http://i.imgur.com/hlrUNId.png -sender Domino -sound Pop -open "$uli_link"
    else
      terminal-notifier -message "$1" -title "Domino" -appIcon http://i.imgur.com/hlrUNId.png -sender Domino -sound Pop
    fi
  fi
}

# Check that we can communicate with the remote Drupal environment and that it is functional
function remotecheck
{
  echo "Checking remote."
  drush cc drush -y >/dev/null 2>&1
  drush acquia-update

  drush @$remote_site.$remote_env vget file_public_path >/dev/null 2>&1

  if [ "$?" -ne "0" ]; then
    echo -e "${RED}ERROR:${NC} You do not have permissions on @$remote_site.$remote_env."
    echo "Or something is wrong with the remote environment."
    echo "Please update your aliases from Acquia, and make sure you can SSH to the server."
    echo "If you are receiving 401 errors, run: drush ac-api-login"
    exit 1
  else
    echo "Remote is up."
  fi
}

# A crash course to install drupal
function quickinstall
{
  echo "Running a quick profile install to get your database off the ground."
  drush $local_site site-install -y
  drush $local_site vset file_public_path "sites/$local_site/files"
  echo; echo "Quick install complete. You should now have a working local Drupal"
}

# Check that we have a funcitonal local Drupal instance running
function localcheck
{
  firsttime="$1"

  echo "Checking local."
  # This is more accurate than a status check, because the db must be up and running.
  drush $local_site vget file_public_path >/dev/null

  if [ "$?" -ne "0" ]
  then
    echo -e "${RED}ERROR:${NC} Could not find a working Drupal instance."
    echo
    echo "Possible causes:"
    echo "   1) This is your first time running this script."
    echo "   2) You have not configured settings.php."
    echo "      Ensure you've set up /docroot/sites/$local_site/settings.php"
    echo "   3) Your local database is empty or corrupt."
    echo "      This might have happened if a backup pulled from Acquia was null,"
    echo "      or if you terminated a previous import before it was complete."
    if [[ $firsttime = "first" ]]
    then
      echo "   4) You forgot to start up your local server (MAMP/Vagrant/etc)."
      echo "   5) An uncaught exception with PHP."
      echo
      read -p "Should we try to continue?" -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]
      then
        quickinstall
        localcheck
      else
        localcheck
      fi
    else
      echo
      read -p "Try again? " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]
      then
        localcheck
      else
        exit 1
      fi
    fi
  else
    echo "Local is up."
  fi
}

# Use drush rsync to update local files to match the remote
function syncfiles
{
  echo "Syncing files from @${site}.${remote_env} to local $local_site."
  echo "This can take a few minutes."
  drush -y rsync @$remote_site.$remote_env:%files $local_site:%files --delete --progress

  echo "File sync complete."; echo
}

# Backup the local MySQL database
function backupdata
{
  MYSQLDUMP=$(which mysqldump);
  if [ "$MYSQLDUMP" = "" ];
  then
    echo -e "${YELLOW}WARNING:${NC} Mysqldump not available. No backup made."
    echo "You should run something like the following (replace version number as needed):"
    echo "$ brew install mysql --client-only --universal ; sudo ln -s /usr/local/Cellar/mysql/5.6.22/bin/mysqldump /usr/local/bin/mysqldump"
  else
    if [ ! -d "$BASEDIR/backups" ]
    then
      echo -e "${YELLOW}NOTICE:${NC} I am creating a folder for your local MySQL backups. You will likely want to add the /backups folder to your gitignore."
      mkdir -p "$BASEDIR/backups" >/dev/null 2>&1
    fi
    echo "Backing up local db to: $BASEDIR/backups/$local_site-$current_time.sql.gz"
    drush $local_site sql-dump > "$BASEDIR/backups/$local_site-$current_time.sql" >/dev/null
    gzip "$BASEDIR/backups/$local_site-$current_time.sql"
  fi
}

# Sync MySQL data using pipe-syncing, which is more likely to succeed with very large databases.
function syncdatawithpipe
{
  echo "Prepping modules for database pipe-syncing."
  drush dl drush_sql_sync_pipe --destination=$HOME/.drush -n >/dev/null 2>&1
  drush cc drush -y >/dev/null 2>&1
  # Install process viewer, if possible
  brew install pv >/dev/null 2>&1

  echo "Pipe-Syncing database LIVE from ${site}.${remote_env} to local $local_site."
  drush -y sql-sync-pipe @$remote_site.$remote_env $local_site --progress

  echo "Live database sync complete."; echo
}

# Get the latest backup ID from Acquia
function getlatestbackupid
{
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
}

# Sync data using an Acquia db backup
function syncdatafrombackup
{
  getlatestbackupid

  mkdir -p $BASEDIR/backups >/dev/null 2>&1
  file="$BASEDIR/backups/$remote_site-$remote_env-$id.sql.gz"
  if [ ! -f $file ]; then
    echo "Downloading backup..."
    drush @$remote_site.$remote_env ac-database-instance-backup-download $remote_site $id --result-file="$file"
  else
    echo "You've already downloaded the latest backup, so using that file."
  fi

  tmpdir=$(mktemp -dt "ac-update")
  gunzip -c "$file" > "$tmpdir/temp.sql"
  if [ "$?" -ne "0" ] ; then
    echo -e "${RED}ERROR:${NC} Something went wrong trying unzip the backup."
    echo "The database backup may be corrupt. Switching to live sync with pipe."
    syncdatawithpipe
  else
    echo "Dropping local SQL tables for accuracy."
    drush -y $local_site sql-drop >/dev/null 2>&1

    echo "Importing backup to local: $local_site"
    drush $local_site sql-cli < "$tmpdir/temp.sql"
    if [ "$?" -ne "0" ]
    then
      echo -e "${RED}ERROR:${NC} Something went wrong trying to import the backup."
      echo "You might need to make sure your local MySQL is running and it's socket is open."
      exit
    fi

    echo "Backup database sync complete."; echo
  fi
}

# Check the status of the features locally
function featurecheck
{
  echo; echo "Checking Features to see if any need reversion (typically they should not)."
  status_fra=$(drush $local_site -n fra)
  if [[ $status_fra == *"following modules will be reverted"* ]]
  then
    status_fra=${status_fra/The following modules will be reverted:/}
    status_fra=${status_fra/Do you really want to continue? (y\/n): n/}
    status_fra=${status_fra/Aborting./}
    status_fra=${status_fra/
/}
    status_fra=${status_fra/,/
  }
    echo -e "${YELLOW}WARNING:${NC} The following features are not reverted:"
    echo "  $status_fra"
  else
    echo "Some features need updating or correction."
    status_fra="clean"
  fi
}

# Correct the local database for most standard local development needs.
function correctdata
{
  echo "Beginning database correction (for local development)."

  echo; echo "Setting variables (the fast way):"
  echo "    Turning on maintenance mode."
  echo "    Configuring devel (5)."
  echo "    Disable Javascript aggrigation for easier development."
  echo "    Set Tealium to: dev."
  echo "    Disable Page caching for easier development."
  echo "    Setting softrip to testing mode"
  echo "    Show ALL errors and warnings in this environment to users."
  echo "    Disable domain redirection"
  echo "    Unlocking Features."
  drush $local_site php-eval "
    variable_set('maintenance_mode', '1');
    variable_set('devel_krumo_skin', 'blue');
    variable_set('devel_memory', '1');
    variable_set('devel_redirect_page', '0');
    variable_set('dev_timer', '1');
    variable_set('devel_error_handlers', array('4' => 4));
    variable_set('preprocess_js', '0');
    variable_set('tealium_environment', 'dev');
    variable_set('cache', '0');
    variable_set('error_level', '2');
    variable_set('syslog_identity', '$local_site.local');
    variable_set('syslog_advanced_identity', '$local_site.local');
    variable_set('domain_301_redirect_enabled', '0');
    variable_del('features_feature_locked');
  "

  echo; echo "Modifying modules fast/dangerous way (saving ~5min):"
  echo "    Disabling (if relevant):"
  echo "        fast_404"
  echo "        memcache_admin"
  echo "        memcache"
  echo "        shield"
  echo "        expire"
  echo "        cloudflare"
  echo "        acquia_spi"
  echo "        acquia_purge"
  echo "        acquia_cloud_sticky_sessions"
  echo "    Enabling:"
  echo "        devel"
  echo "        diff"
  echo "        field_ui"
  echo "        views_ui"
  echo "        xhprof"
  drush $local_site -y sql-query "
    UPDATE system SET status = 0 WHERE name IN (
      'fast_404',
      'memcache_admin',
      'memcache',
      'shield',
      'expire',
      'acquia_spi',
      'acquia_purge',
      'cloudflare',
      'acquia_cloud_sticky_sessions'
    );
    UPDATE system SET status = 1 WHERE name IN (
      'devel',
      'diff',
      'field_ui',
      'views_ui',
      'xhprof',
      'contextual'
    );" >/dev/null 2>&1

  echo; echo "Setting all passwords to: $local_site"
  # drush $local_site -y sql-sanitize --sanitize-password=$local_site --sanitize-email=no
  # sql-sanitize is somewhat distructive to local environments
  # when the paranoia module is enabled. The Authmap is not present, for example.
  # So the following method is a replacement
  cd "$BASEDIR"
  hash=$( drush $local_site php-eval "
    define('DRUPAL_ROOT', getcwd());
    include_once DRUPAL_ROOT . '/includes/password.inc';
    echo user_hash_password('$local_site');")
  cd -
  drush $local_site -y sql-query "UPDATE users SET pass = '$hash' WHERE uid <> 0;" >/dev/null 2>&1

  if [ "$3" != "fast" ]
  then
    echo; echo "Rebuilding registry."
    drush $local_site -y rr
  fi

  echo; echo "Checking update status."
  updb_status=$( drush $local_site -y updatedb-status 2>&1 )
  if [[ $updb_status != "No database updates required"* ]]
  then
    echo; echo "Updating database and clearing caches."
    drush $local_site -y updatedb
  else
    echo "No database updates required, skipping!"
  fi

  echo; echo "Turning off maintenance mode & flushing all caches."
  drush $local_site php-eval "
    variable_set('maintenance_mode', '0');
    drupal_flush_all_caches();"

  echo "Database correction complete."; echo

  if [ "$3" != "fast" ]
  then
    featurecheck
  fi
}

# Ask the usuer to select a mechanism of syncing data
function syncdatachoice
{
  options=("Latest backup (default)", "Live database (piped directly from the environment)")
  PS3="Choose a database: "
  select opt in "${options[@]}" "Quit"; do
      echo
      case "$REPLY" in

      1 ) remotecheck; localcheck first; syncdatafrombackup; localcheck; exit;;
      2 ) remotecheck; localcheck first; syncdatawithpipe; localcheck; exit;;

      $(( ${#options[@]}+1 )) ) echo "See ya!";
          break;;

      *) echo "Invalid option. Try again.";
          continue;;

      esac
  done
}

# Run a standard git pull (assuming we are in a git repository)
function gitpull
{
  echo "Running git pull (not changing branches)."
  git pull
  echo "Your git status:"
  git status
}

# If a /contributions folder exists next to the docroot, synchronize it.
function contributions
{
  echo "Checking for contributions to be linked."
  if [ -d "$BASEDIR/../contributions" ]
  then
    # Get the absolute path to the profile directory
    local SITESALL="$BASEDIR/sites/all"

    # Get the absolute path to the externals folder
    cd "$BASEDIR/../contributions"
    local CONTRIBUTIONSDIR="$(pwd)"
    local COUNTER=0

    # Modules
    cd "$CONTRIBUTIONSDIR/modules"
    for dir in *
    do
        if [[ -d "$dir" && ! -L "$dir" ]]
        then
          destdir="$SITESALL/modules/contrib/$dir"
          sourcedir="$CONTRIBUTIONSDIR/modules/$dir"
          if [[ -d "$destdir" && ! -L "$destdir" ]]
          then
            echo -e "${YELLOW}NOTICE:${NC} Contrib module $dir is being replaced with a link to /contributions/modules/$dir"
            rm -rf "$destdir"
          fi
          if [[ -L "$destdir" ]]
          then
            echo -e "$dir was already linked!"
          else
            ln -s "$sourcedir" "$destdir"
            echo -e "${GREEN}LINKED:${NC} $dir to /contributions/modules/$dir"
            let COUNTER=COUNTER+1
          fi
        fi
    done
    echo "Linked $COUNTER module contributions."
    COUNTER=0

    # Libraries
    cd "$CONTRIBUTIONSDIR/libraries"
    for dir in *
    do
        if [[ -d "$dir" && ! -L "$dir" ]]
        then
          destdir="$SITESALL/libraries/$dir"
          sourcedir="$CONTRIBUTIONSDIR/libraries/$dir"
          if [[ -d "$destdir" && ! -L "$destdir" ]]
          then
            echo -e "${YELLOW}NOTICE:${NC} Library $dir is being replaced with a link to /contributions/libraries/$dir"
            rm -rf "$destdir"
          fi
          if [[ -L "$destdir" ]]
          then
            echo -e "$dir was already linked!"
          else
            ln -s "$sourcedir" "$destdir"
            echo -e "${GREEN}LINKED:${NC} $dir to /contributions/libraries/$dir"
            let COUNTER=COUNTER+1
          fi
        fi
    done
    echo "Linked $COUNTER library contributions."
    COUNTER=0
    cd "$BASEDIR"
  else
    echo "No contributions folder found next to your docroot."
  fi
}

function securitycheck
{
  echo "Running security check on all modules (this may take a while)."
  drush $local_site -y en update >/dev/null 2>&1
  status_security=$(drush $local_site ups --security-only)
  status_security=${status_security/Checking available update data ...                                             [ok]/}
  echo
  if [[ $status_security == *"SECURITY UPDATE"* ]]
  then
    echo -e "${RED}WARNING:${NC} Security updates needed!"
    echo "$status_security"
  else
    echo "No security updates needed at this time."
    status_security="clean"
  fi
}

# Express a summary of feature/security issues found, if any
function summary
{
  echo "________________________________________________________________________________"
  echo "Summary:"
  echo

  if [[ $status_security == "unknown" ]]
  then
    echo -e "Security status: ${YELLOW}UNKNOWN${NC}  (run: Correct local database, or Security check)"
  fi

  if [[ $status_security == "clean" ]]
  then
    echo -e "Security status: ${GREEN}SECURE${NC}"
  fi

  if [[ $status_security != "unknown" ]] &&  [[ $status_security != "clean" ]]
  then
    echo -e "Security status: ${RED}INSECURE${NC}"
    echo "$status_security"
  fi

  if [[ $status_fra == "unknown" ]]
  then
    echo -e "Features status: ${YELLOW}UNKNOWN${NC}  (run: Correct local database)"
  fi

  if [[ $status_fra == "clean" ]]
  then
    echo -e "Features status: ${GREEN}CLEAN${NC}"
  fi

  if [[ $status_fra != "unknown" ]] &&  [[ $status_fra != "clean" ]]
  then
    echo -e "Features status: ${RED}UNSTABLE${NC}"
    echo "  $status_fra"
  fi
}

function allfunctions
{
  echo "Performing all functions with backups."
  note "Performing all functions with backups."
  gitpull
  contributions
  remotecheck
  localcheck first
  backupdata
  syncdatafrombackup
  localcheck
  correctdata
  note "Database updates done. You can jump into Drupal now or wait till files are synced." 1
  syncfiles
  securitycheck
  summary
  note "All finished updating. Click here to open!" 1
}

function allfunctionsfast
{
  echo "Performing fast functions (database only, no checking)."
  note "Performing fast functions (database only, no checking)."
  gitpull
  contributions
  remotecheck
  localcheck first
  # backupdata
  syncdatafrombackup
  localcheck
  correctdata
  # note "Database updates done. Syncing files now. You can jump into Drupal now." 1
  # syncfiles
  # securitycheck
  # summary
  note "All finished updating. Click here to open!" 1
}

function allfunctionslive
{
  echo "Performing all functions with live data."
  note "Performing all functions with live data."
  gitpull
  contributions
  remotecheck
  localcheck first
  backupdata
  syncdatawithpipe
  localcheck
  correctdata
  note "Database updates done. You can jump into Drupal now or wait till files are synced." 1
  syncfiles
  securitycheck
  summary
  note "All finished updating. Click here to open!" 1
}

# Start a timer
function tstart
{
  starttime=$(date +%s)
}

# End a timer, showing the duration
function tend
{
  endtime=$(date +%s)
  echo "Duration: $(($endtime - $starttime)) seconds."; echo
}

# Run preselected option, or provide a menu
case "$3" in
  all ) tstart; allfunctions; tend; exit;;
  live ) tstart; allfunctionslive; tend; exit;;
  fast ) tstart; allfunctionsfast; tend; exit;;
  *) options=("Git pull (on current branch)." "Run make." "Symlink module/library contributions" "Back up local database." "Pull down database." "Correct local database (updb, fra, etc)." "Check feature stability." "Pull down files." "Check modules for security updates." "All of the above (using backup)." "All of the above (using live data).")
    PS3="Choose a function: "
    select opt in "${options[@]}" "Quit"; do
        echo
        case "$REPLY" in

        1 ) tstart; gitpull; tend; exit;;
        2 ) tstart; cleanup; makephprun; tend; exit;;
        3 ) tstart; contributions; tend; exit;;
        4 ) tstart; localcheck first; backupdata; tend; exit;;
        5 ) tstart; syncdatachoice; tend; exit;;
        6 ) tstart; localcheck first; correctdata; summary; tend; exit;;
        7 ) tstart; featurecheck; tend; exit;;
        8 ) tstart; remotecheck; localcheck first; syncfiles; tend; exit;;
        9 ) tstart; securitycheck; tend; exit;;
        10 ) tstart; allfunctions; tend; exit;;
        11 ) tstart; allfunctionslive; tend; exit;;

        $(( ${#options[@]}+1 )) ) echo "See ya!";
            break;;

        *) echo "Invalid option. Try again, looser.";
            continue;;

        esac
    done
    exit ;;
esac
