#!/usr/bin/env bash

###########################
####### LOAD CONFIG #######
###########################

while [ $# -gt 0 ]; do
  case $1 in
    -c)
    CONFIG_FILE_PATH="$2"
    shift 2
    ;;
    *)
    ${ECHO} "Unknown Option \"$1\"" 1>&2
    exit 2
    ;;
  esac
done

if [ -z $CONFIG_FILE_PATH ] ; then
  SCRIPTPATH=$(cd ${0%/*} && pwd -P)
  CONFIG_FILE_PATH="${SCRIPTPATH}/mysql_backup.config"
fi

if [ ! -r ${CONFIG_FILE_PATH} ] ; then
  echo "Could not load config file from ${CONFIG_FILE_PATH}" 1>&2
  exit 1
fi

source "${CONFIG_FILE_PATH}"

###########################
#### PRE-BACKUP CHECKS ####
###########################

# Make sure we're running as the required backup user
if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ] ; then
  echo "This script must be run as $BACKUP_USER. Exiting." 1>&2
  exit 1
fi


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

function perform_backups()
{
  SUFFIX=$1
  FINAL_BACKUP_DIR=$BACKUP_DIR"`date +\%Y\%m\%d\-\%H\%M`$SUFFIX/"

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
}

# MONTHLY BACKUPS

DAY_OF_MONTH=`date +%d`

if [ $DAY_OF_MONTH -eq 1 ];
then
  # Delete all expired monthly directories
  find $BACKUP_DIR -maxdepth 1 -name "*-monthly" -exec rm -rf '{}' ';'

  perform_backups "-monthly"

  exit 0;
fi

# WEEKLY BACKUPS

DAY_OF_WEEK=`date +%u` #1-7 (Monday-Sunday)
EXPIRED_DAYS=`expr $((($WEEKS_TO_KEEP * 7) + 1))`

if [ $DAY_OF_WEEK = $DAY_OF_WEEK_TO_KEEP ];
then
  # Delete all expired weekly directories
  find $BACKUP_DIR -maxdepth 1 -mtime +$EXPIRED_DAYS -name "*-weekly" -exec rm -rf '{}' ';'

  perform_backups "-weekly"

  exit 0;
fi

# DAILY BACKUPS

# Delete daily backups 7 days old or more
find $BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP -name "*-daily" -exec rm -rf '{}' ';'

perform_backups "-daily"

# perform S3 sync
# aws s3 sync $BACKUP_DIR s3://$AWS_BUCKET
