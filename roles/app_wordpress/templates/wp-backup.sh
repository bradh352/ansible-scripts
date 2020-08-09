#!/bin/bash

LOCAL_TEMP="/tmp/wpbackup"
REMOTE_PREFIX="WordpressBackups"
LOCAL_SITEPATH="{{ wordpress_install_path }}"
DOMAIN="{{ wordpress_domain }}"
# Days to retain
DAYSKEEP=30

DATE_CURRENT=`date +"%Y-%m-%d"`
DATE_OLDEST=`date +"%Y-%m-%d" -d "-${DAYSKEEP} days"`

export PATH="$PATH:/usr/bin:/bin:/usr/local/bin"

# we have hardening settings that cause issues, so we have a php-cli-specific config dir
export PHP_INI_SCAN_DIR=/etc/php-cli.d/

WP=/usr/local/bin/wp

die() {
	echo "$*"
	exit 1
}

# make sure the temporary path exists
mkdir -p "${LOCAL_TEMP}" || die "failed to create ${LOCAL_TEMP}"

echo "Starting WordPress Backup of ${DOMAIN} at ${LOCAL_SITEPATH}"

cd "${LOCAL_SITEPATH}" || die "failed to cd to ${LOCAL_SITEPATH}"

# make sure the remote path exists
${WP} gdrive mkdir "${REMOTE_PREFIX}" --quiet || die "failed to create remote google drive path ${REMOTE_PREFIX}"

# check remote backup folder exists on gdrive
#   Its formatted as a table, so we have to do quite a bit of manipulation
#   All files we care about are prefixed with "wpbackup-"
REMOTE_FILE_LIST=`${WP} gdrive ls "${REMOTE_PREFIX}" 2>/dev/null | cut -d'|' -f 2 | grep -v '+$' | sed -e 's/ *$//' -e 's/^ //' -e '1d' | grep -i '^wpbackup-'`

echo " * Remote file list:"
echo "${REMOTE_FILE_LIST}"

# clear all files that are older than we want to keep
while read -r file ; do
	if [ "${file}" = "" ] ; then
		continue
	fi
	name=`echo $file | sed -e 's/.tar.gz//' -e 's/.sql.gz//'`

	echo "   * Comparing ${name} to wpbackup-${DATE_OLDEST}"
	# Delete files less than oldest allowed date
	if [[ "${name}" < "wpbackup-${DATE_OLDEST}" ]] ; then
		echo " * Deleting ${REMOTE_PREFIX}/${file}"
		${WP} gdrive rm "${REMOTE_PREFIX}/${file}" --force --quiet || die "failed to delete remote google drive file ${REMOTE_PREFIX}/${file}"
	else
		echo " * Keeping ${REMOTE_PREFIX}/${file}"
	fi
done < <(echo "$REMOTE_FILE_LIST")


# Back up the wordpress wp-content folder
BACKUP_NAME="wpbackup-${DATE_CURRENT}-${DOMAIN}"
echo " * Backing up wp-content"
rm -f "${LOCAL_TEMP}/${BACKUP_NAME}.tar.gz"
tar -zcpf "${LOCAL_TEMP}/${BACKUP_NAME}.tar.gz" wp-content || die "failed to create wp-content .tar.gz"


# Backup the wordpress database
echo " * Backing up wordpress database"
rm -f "${LOCAL_TEMP}/${BACKUP_NAME}.sql.gz"
$WP db export - --all-tablespaces --single-transaction --quick --lock-tables=false --allow-root --skip-plugins --skip-themes | gzip > "${LOCAL_TEMP}/${BACKUP_NAME}.sql.gz" || die "failed to backup sql data"

# Upload
echo " * Uploading backups"
# Can't upload from an absolute path, so cd to where the files are
cd "${LOCAL_TEMP}"
$WP gdrive upload "${BACKUP_NAME}.tar.gz" "${REMOTE_PREFIX}" --force --quiet || die "failed to upload wp-content backup data to google drive"
$WP gdrive upload "${BACKUP_NAME}.sql.gz" "${REMOTE_PREFIX}" --force --quiet || die "failed to upload sql backup data to google drive"

# Cleanup
rm -f "${LOCAL_TEMP}/${BACKUP_NAME}.tar.gz"
rm -f "${LOCAL_TEMP}/${BACKUP_NAME}.sql.gz"

echo "DONE"
exit 0
