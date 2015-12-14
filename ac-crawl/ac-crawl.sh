#!/bin/bash
# Crawls a site using wget to warm caches and provide feedback to NewRelic. Skips files on command.

if [ "$1" = "" ]
then
  echo "Retrieves past and present logs for a site in Acquia Enterprise."
  read -p "URL to crawl: " url
else
  url="$1"
  echo "URL to crawl: $url"
fi

logstreamloc=$(which logstream);
if [ "$logstreamloc" = "" ];
then
  brew install wget
fi

path=`pwd`

read -p "Username [none]: " user
read -p "Password [none]: " pass
read -p "Save site to [$path]: " path

cd $path

PS3='Select a mode: '
options=("Mirror   - Fast, complete copy of site. Can be dangerous." "Test     - Moderate, no files, used to find performance hogs in NewRelic." "Warm     - Slow, no files, just to safely warm caches, say after a deployment." "Simulate - Very slow, as if a typical user." "Quit")
select opt in "${options[@]}"
do
  case $REPLY in
    1 ) echo "Mirror mode selected."
        wget --mirror --convert-links --adjust-extension --page-requisites --no-parent --user=$user --password=$pass $url
        cd - ; exit ;;
    2 ) echo "Testing mode selected."
        wget --mirror --convert-links --adjust-extension --page-requisites --no-parent --user=$user --password=$pass --random-wait --reject=gif,jpg,jpeg,pdf,png,css,js $url
        cd - ; exit ;;
    3 ) echo "Cache warming mode selected."
        wget --mirror --convert-links --adjust-extension --page-requisites --no-parent --user=$user --password=$pass --limit-rate=100k --random-wait --reject=gif,jpg,jpeg,pdf,png,css,js $url
        cd - ; exit ;;
    4 ) echo "Simulation mode selected."
        wget --mirror --convert-links --adjust-extension --page-requisites --no-parent --user=$user --password=$pass --limit-rate=100k --wait=20 --reject=gif,jpg,jpeg,pdf,png,css,js $url
        cd - ; exit ;;
    5 ) exit ;;
    * ) echo "invalid option" ;;
  esac
done
