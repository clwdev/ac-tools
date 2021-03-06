#!/bin/bash
# Crawls a site using wget to warm caches and provide feedback to NewRelic. Skips files on command.
#
# Full CLI Mode:
# ./ac-crawl.sh url discard [--user=username --password=password]
# (Username and Password are optional. Technically you can also pass extra parameters into wget this way.)

set +e

if [ "$1" = "" ]
then
  echo "Crawls a site using wget to warm caches and provide baseline perf results in NewRelic. Skips files on command."
  read -p "URL to crawl: " url
else
  url="$1"
fi

wgetloc=$(which wget);
if [ "$wgetloc" = "" ];
then
  brew install wget
fi

function cleanup {
  rm -rf "$path"
  echo ; echo "Cleanup of $path complete."
}

if [ "$2" = "discard" ]
then
  path=`mktemp -d`
  trap cleanup EXIT
else 
  path=`pwd`
  read -p "Save site to [$path]: " path
fi

if [ "$3" = "" ]
then
  # no user info passed in
  read -p "Username [none]: " user
  if [ -z "$user" ]
  then
    auth=""
  else
    read -p "Password [none]: " pass
    auth="--user=$user --password=$pass"
  fi
else
  # assume user and password were passed in
  auth="${@:3}"
fi

cd $path

if [ "$2" = "" ]
then
  PS3='Select a mode: '
  options=(
    "Mirror   - Fast, complete copy of site. Can be dangerous."
    "Test     - Moderate, no files, used to find performance hogs in NewRelic."
    "Warm     - Slow, no files, just to safely warm caches, say after a deployment."
    "Simulate - Very slow, as if a typical user."
    "Quit"
  )
  select opt in "${options[@]}"
  do
    case $REPLY in
      1 ) echo "Mirror mode selected."
          wget --mirror --convert-links --adjust-extension --page-requisites --no-parent $auth $url
          cd - ; exit ;;
      2 ) echo "Testing mode selected."
          wget --mirror --convert-links --adjust-extension --page-requisites --no-parent $auth --random-wait --reject=gif,jpg,jpeg,pdf,png,css,js $url
          cd - ; exit ;;
      3 ) echo "Cache warming mode selected."
          wget --mirror --convert-links --adjust-extension --page-requisites --no-parent $auth --limit-rate=100k --random-wait --reject=gif,jpg,jpeg,pdf,png,css,js $url
          cd - ; exit ;;
      4 ) echo "Simulation mode selected."
          wget --mirror --convert-links --adjust-extension --page-requisites --no-parent $auth --limit-rate=100k --wait=20 --reject=gif,jpg,jpeg,pdf,png,css,js $url
          cd - ; exit ;;
      5 ) exit ;;
      * ) echo "invalid option" ;;
    esac
  done
else
  # Non-Interactive Mode
  wget --recursive --level=100 --page-requisites --no-parent --adjust-extension --reject=gif,jpg,jpeg,pdf,png,css,js,"*devel*" --reject-regex '(.*)\?(.*)' --no-clobber --timeout=300 --no-dns-cache --no-cache --no-verbose $auth $url
  cd -
  exit 0
fi
