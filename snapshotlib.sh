#!/usr/bin/env bash
# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility
# http://www.mikerubel.org/computers/rsync_snapshots/
# ----------------------------------------------------------------------
# this needs to be a lot more general, but the basic idea is it makes
# rotating backup-snapshots of /home whenever called
# ----------------------------------------------------------------------

# suggestion from H. Milz: avoid accidental use of $PATH
unset PATH

# ------------- helper functions -----------------------------------------

mount_backup_dir_rw ()
{
    local mount_device=$1;
    local backup_dir=$2;

    # attempt to remount the RW mount point as RW; else abort
    $MOUNT -o remount,rw ${mount_device} ${backup_dir} ;
    if (( $? )); then
    {
        $ECHO "snapshot: could not remount ${backup_dir} readwrite";
        exit;
    }
    fi;
}


mount_backup_dir_ro ()
{
    local mount_device=$1;
    local backup_dir=$2;

    # now remount the RW snapshot mountpoint as readonly
    $MOUNT -o remount,ro ${mount_device} ${backup_dir} ;
    if (( $? )); then
    {
        $ECHO "snapshot: could not remount ${backup_dir} readonly";
        exit;
    }
    fi;
}


rotate_hourly_backups ()
{
    local dest_dir=$1;

    # rotating hourly snapshots

    # step 1: delete the oldest snapshot, if it exists:
    if [ -d ${dest_dir}/hourly.3 ] ; then
        $RM -rf ${dest_dir}/hourly.3 ;
    fi ;

    # step 2: shift the middle snapshots(s) back by one, if they exist
    if [ -d ${dest_dir}/hourly.2 ] ; then
        $MV ${dest_dir}/hourly.2 ${dest_dir}/hourly.3 ;
    fi;
    if [ -d ${dest_dir}/hourly.1 ] ; then
        $MV ${dest_dir}/hourly.1 ${dest_dir}/hourly.2 ;
    fi;

    # step 3: make a hard-link-only (except for dirs) copy of the
    # latest snapshot, if that exists
    if [ -d ${dest_dir}/hourly.0 ] ; then
        $CP -al ${dest_dir}/hourly.0 ${dest_dir}/hourly.1 ;
    fi;
}


rotate_daily_backups ()
{
    local dest_dir=$1;

    # step 1: delete the oldest snapshot, if it exists:
    if [ -d ${dest_dir}/daily.2 ] ; then
        $RM -rf ${dest_dir}/daily.2 ;
    fi ;

    # step 2: shift the middle snapshots(s) back by one, if they exist
    if [ -d ${dest_dir}/daily.1 ] ; then
        $MV ${dest_dir}/daily.1 ${dest_dir}/daily.2 ;
    fi;
    if [ -d ${dest_dir}/daily.0 ] ; then
        $MV ${dest_dir}/daily.0 ${dest_dir}/daily.1;
    fi;

    # step 3: make a hard-link-only (except for dirs) copy of
    # hourly.3, assuming that exists, into daily.0
    if [ -d ${dest_dir}/hourly.3 ] ; then
        $CP -al ${dest_dir}/hourly.3 ${dest_dir}/daily.0 ;
    fi;

    # note: do *not* update the mtime of daily.0; it will reflect
    # when hourly.3 was made, which should be correct.
}


backup ()
{
    local source_dir=$1;
    local dest_dir=$2/hourly.0;

    # if the destination directory does not exist, create it.
    if [[ ! -d ${dest_dir} ]] ; then
        ${MKDIR} -p ${dest_dir};
    fi ;

    # step 4: rsync from the system into the latest snapshot (notice that
    # rsync behaves like cp --remove-destination by default, so the destination
    # is unlinked first.  If it were not so, this would copy over the other
    # snapshot(s) too!

    # unused flags:
    #    --delete-excluded \
    #    --exclude-from="$EXCLUDES" \

    $RSYNC \
        -va \
        --delete \
        -e "ssh -i ${SSH_IDENTITY} \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null" \
        ${source_dir} ${dest_dir};

    # step 5: update the mtime of hourly.0 to reflect the snapshot time
    $TOUCH ${dest_dir};
}


rotate_and_backup ()
{
    local source_dir=$1;
    local dest_dir=$2;

    rotate_hourly_backups ${dest_dir};
    backup ${source_dir} ${dest_dir};
}

