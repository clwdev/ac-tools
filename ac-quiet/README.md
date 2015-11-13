# ac-quiet

`ac-quiet` is a simple "Quiet Hours" script that determines if a supplied Acquia Cloud Site has anything actively running. It uses `drush` and your Acquia Cloud plugins to loop through `ac-task-list` until it's clear. Then when it's done it'll use `terminal-notifier` to tell you it's done.

Script presently only officially works on OS X, though I guess it would work on Linux if you had Brew installed. . . alternatively it could be expanded to install via the gem.