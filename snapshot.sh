#!/usr/bin/env bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  # if $SOURCE was a relative symlink, we need to resolve
  # it relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# load local configuration
source ${DIR}/snapshot.config

# load additional library functions
source ${DIR}/snapshotlib.sh

# NOTE: don't exit on error, or the mount device may not be
#        remounted read-only

# make sure we're running as root
if (( `$ID -u` != 0 )); then
    $ECHO "Sorry, must be root.  Exiting...";
    exit;
fi ;

mount_backup_dir_rw ${MOUNT_DEVICE} ${SNAPSHOT_RW};

# the ending slash (/) in SOURCE matters.
#
# SOURCE="/home/";
# DESTINATION="${SNAPSHOT_RW}/home";
# rotate_and_backup ${SOURCE} ${DESTINATION};
#
# example remote host host1
# rotate_and_backup \
#        "user@host1:/home/user/" \
#        "${SNAPSHOT_RW}/host1";
#
# example local directory one host2
# rotate_and_backup \
#        "/home/user/" \
#        "${SNAPSHOT_RW}/host2";

for k in "${!backups[@]}" ; do
    rotate_and_backup ${backups[${k}]} ${SNAPSHOT_RW}/${k};
done


# FIXME: remount ro if above command fails

mount_backup_dir_ro ${MOUNT_DEVICE} ${SNAPSHOT_RW};
