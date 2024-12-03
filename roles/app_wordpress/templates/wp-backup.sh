#!/bin/bash

# If any command in a chained pipe returns failure, count it as a failure
set -o pipefail

. /usr/local/bin/gdrive.sh

LOCAL_TEMP="/tmp/wpbackup"
REMOTE_PREFIX="WordpressBackups"
LOCAL_SITEPATH="{{ wordpress_install_path }}"
DOMAIN="{{ wordpress_domain }}"
# Days to retain
DAYSKEEP=30

DATE_CURRENT=`date +"%Y-%m-%d"`
DATE_OLDEST=`date +"%Y-%m-%d" -d "-${DAYSKEEP} days"`

export PATH="$PATH:/usr/bin:/bin:/usr/local/bin"
export COLUMNS=1000  # Don't truncate output

# we have hardening settings that cause issues, so we have a php-cli-specific config dir
export PHP_INI_SCAN_DIR=/etc/php-cli.d/

WP=/usr/local/bin/wp

log() {
	logger -t wpbackup -p cron.notice "$*"
}

log_pipe() {
	{ sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\r//g' -e 's/Upload .*%] *//g' -e 's/Please wait ...//g' || true; } | logger -t wpbackup -p cron.notice
}

die() {
	log "$*"
	echo "$*"
	exit 1
}

# make sure the temporary path exists
mkdir -p "${LOCAL_TEMP}" 2>&1 | log_pipe || die "failed to create ${LOCAL_TEMP}"

log "Starting WordPress Backup of ${DOMAIN} at ${LOCAL_SITEPATH}"

if [ ! -d "${LOCAL_SITEPATH}" ] ; then
	die "'${LOCAL_SITEPATH}'' does not exist"
fi

cd "${LOCAL_SITEPATH}" || die "failed to cd to ${LOCAL_SITEPATH}"

# make sure the remote path exists
if ! gdrive_directory_exists "${REMOTE_PREFIX}" ; then
	gdrive_directory_create "${REMOTE_PREFIX}" 2>&1 | log_pipe || die "failed to create remote google drive path ${REMOTE_PREFIX}"
fi

log " * Retrieving remote file list"

# check remote backup folder exists on gdrive
#   Its formatted as a table, so we have to do quite a bit of manipulation
#   All files we care about are prefixed with "wpbackup-"
REMOTE_FILE_LIST=`gdrive_ls "${REMOTE_PREFIX}" 2>/dev/null | grep -i '^wpbackup-'`

# clear all files that are older than we want to keep
while read -r file ; do
	if [ "${file}" = "" ] ; then
		continue
	fi
	name=`echo $file | sed -e 's/.tar.gz//' -e 's/.sql.gz//'`

	# Delete files less than oldest allowed date
	if [[ "${name}" < "wpbackup-${DATE_OLDEST}" ]] ; then
		log " * Deleting ${REMOTE_PREFIX}/${file}"
		(gdrive_rm "${REMOTE_PREFIX}/${file}") 2>&1 | log_pipe || die "failed to delete remote google drive file ${REMOTE_PREFIX}/${file}"
	fi
done < <(echo "$REMOTE_FILE_LIST")


# Back up the wordpress wp-content folder
BACKUP_NAME="wpbackup-${DATE_CURRENT}-${DOMAIN}"
log " * Backing up wp-content"
rm -f "${LOCAL_TEMP}/${BACKUP_NAME}.tar.gz"
(tar -zcpf "${LOCAL_TEMP}/${BACKUP_NAME}.tar.gz" wp-content) 2>&1 | log_pipe || die "failed to create wp-content .tar.gz"


# Backup the wordpress database
log " * Backing up wordpress database"
rm -f "${LOCAL_TEMP}/${BACKUP_NAME}.sql.gz"
($WP db export - --all-tablespaces --single-transaction --quick --lock-tables=false --allow-root --skip-plugins --skip-themes --no-color | gzip > "${LOCAL_TEMP}/${BACKUP_NAME}.sql.gz") 2>&1 | log_pipe || die "failed to backup sql data"

# Upload
log " * Uploading backups"
# Can't upload from an absolute path, so cd to where the files are
cd "${LOCAL_TEMP}" || die "failed to cd to ${LOCAL_TEMP}"
(gdrive_upload "${BACKUP_NAME}.tar.gz" "${REMOTE_PREFIX}") 2>&1 | log_pipe || die "failed to upload wp-content backup data to google drive"
(gdrive_upload "${BACKUP_NAME}.sql.gz" "${REMOTE_PREFIX}") 2>&1 | log_pipe || die "failed to upload sql backup data to google drive"

# Cleanup
rm -f "${LOCAL_TEMP}/${BACKUP_NAME}.tar.gz"
rm -f "${LOCAL_TEMP}/${BACKUP_NAME}.sql.gz"

log "DONE"
exit 0
