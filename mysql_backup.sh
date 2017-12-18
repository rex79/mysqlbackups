#!/usr/bin/env bash

###########################
####### LOAD CONFIG #######
###########################

while [ $# -gt 0 ]; do
  case $1 in
    -c)
    if [ -r "$2" ]; then
      source "$2"
      shift 2
    else
      ${ECHO} "Unreadable config file \"$2\"" 1>&2
      exit 1
    fi
    ;;
    *)
    ${ECHO} "Unknown Option \"$1\"" 1>&2
    exit 2
    ;;
  esac
done

if [ $# = 0 ]; then
  SCRIPTPATH=$(cd ${0%/*} && pwd -P)
  source $SCRIPTPATH/mysql_backup.config
fi;

###########################
#### PRE-BACKUP CHECKS ####
###########################

# Make sure we're running as the required backup user
if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ]; then
  echo "This script must be run as $BACKUP_USER. Exiting." 1>&2
  exit 1;
fi;


###########################
### INITIALISE DEFAULTS ###
###########################

if [ ! $HOSTNAME ]; then
  HOSTNAME="localhost"
fi;

if [ ! $USERNAME ]; then
  USERNAME="root"
fi;

# Make sure we have a password for make the backup
if [ ! $PASSWORD ]; then
  echo "This script must be run with a password for user $BACKUP_USER. Exiting." 1>&2
  exit 1;
fi;

###########################
#### START THE BACKUPS ####
###########################


FINAL_BACKUP_DIR=$BACKUP_DIR"`date +\%Y\%m\%d\-\%H\%m`/"

echo "Making backup directory in $FINAL_BACKUP_DIR"

if ! mkdir -p $FINAL_BACKUP_DIR; then
  echo "Cannot create backup directory in $FINAL_BACKUP_DIR. Go and fix it!" 1>&2
  exit 1;
fi;


#######################
### GLOBALS BACKUPS ###
#######################

echo -e "\n\nPerforming globals backup"
echo -e "--------------------------------------------\n"

if [ $ENABLE_GLOBALS_BACKUPS = "yes" ]
then
  echo "Globals backup"

  if ! mysqldump -u "$USERNAME" -p"$PASSWORD" -A -R -E --triggers --single-transaction | gzip > $FINAL_BACKUP_DIR"globals".sql.gz.in_progress; then
    echo "[!!ERROR!!] Failed to produce globals backup" 1>&2
  else
    mv $FINAL_BACKUP_DIR"globals".sql.gz.in_progress $FINAL_BACKUP_DIR"globals".sql.gz
  fi
else
  echo "None"
fi


echo -e "\nAll database backups complete!"
