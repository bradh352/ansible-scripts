#!/bin/bash

# This script requires OAUTH authentication with Google Drive.  That means
# you must have run the gdrive authentication at least once.
#
# Docs here:
#  https://github.com/glotlabs/gdrive/blob/main/docs/create_google_api_credentials.md
#
# Binary is installed to /usr/local/bin/gdrive-{{ gdrive_version }}
#
# You'll note that there will be a final redirect to 127.0.0.1:SOMEPORT that will
# fail in your local browser, copy the url and open another ssh shell into the
# machine and do something like:
#  curl -O "http://127.0.0.1:8085/?code=4/....."
# you'll see the authorization window will finish after that.


# If any command in a chained pipe returns failure, count it as a failure
set -o pipefail

. /usr/local/bin/gdrive.sh

REMOTE_PREFIX="WordpressBackups"
LOCAL_SITEPATH="{{ wordpress_install_path }}"
DOMAIN="{{ wordpress_domain }}"

export PATH="$PATH:/usr/bin:/bin:/usr/local/bin"
export COLUMNS=1000  # Don't truncate output

# we have hardening settings that cause issues, so we have a php-cli-specific config dir
export PHP_INI_SCAN_DIR=/etc/php-cli.d/

WP=/usr/local/bin/wp

die() {
	echo "$*"
	exit 1
}

if [ $# != 1 ] ; then
	die "Usage: $0 <YYYY-MM-DD|latest>"
fi

echo "Starting WordPress Restore of ${DOMAIN} at ${LOCAL_SITEPATH}"

if [ ! -d "${LOCAL_SITEPATH}" ] ; then
	die "'${LOCAL_SITEPATH}' does not exist"
fi

BACKUP_DATE="$1"

if [ "$BACKUP_DATE" == "latest" ] ; then
	echo " * Retrieving remote file list"
	BACKUP_DATE=`gdrive_ls "${REMOTE_PREFIX}" 2>/dev/null | grep -i "^wpbackup-.*-${DOMAIN}" | sed -E 's/.*([0-9]{4})-([0-9]{2})-([0-9]{2}).*/\1-\2-\3/' | sort -r | head -n1`
	if [ "$BACKUP_DATE" = "" ] ; then
		die "no backups found"
	fi
	echo " * Using backup date $BACKUP_DATE"
fi

BACKUP_NAME="wpbackup-${BACKUP_DATE}-${DOMAIN}"
echo " * Downloading wp-content ${BACKUP_NAME}.tar.gz"
(gdrive_download "${REMOTE_PREFIX}/${BACKUP_NAME}.tar.gz" /tmp) 2>&1 || die "failed to download wp-content backup data from google drive"

echo " * Downloading database ${BACKUP_NAME}.sql.gz"
(gdrive_download "${REMOTE_PREFIX}/${BACKUP_NAME}.sql.gz" /tmp) 2>&1 || die "failed to download database backup data from google drive"

echo " * Restoring wordpress content"
rm -rf "${LOCAL_SITEPATH}/wp-content/*"
(tar -zxpf "/tmp/${BACKUP_NAME}.tar.gz" -C "${LOCAL_SITEPATH}") 2>&1 || die "failed to extract wordpress content"
chown -R apache:apache "${LOCAL_SITEPATH}/wp-content" || die "failed to set ownership on wordpress content"
restorecon -R "${LOCAL_SITEPATH}/wp-content" || die "failed to set SELinux rules on wordpress content"

echo " * Restoring wordpress database"
cd "${LOCAL_SITEPATH}"
(gunzip -c "/tmp/${BACKUP_NAME}.sql.gz" | $WP db import --path="${LOCAL_SITEPATH}" -) 2>&1 || die "failed to restore database"

# Cleanup

rm -f "/tmp/${BACKUP_NAME}.tar.gz"
rm -f "/tmp/${BACKUP_NAME}.sql.gz"

echo "DONE"
exit 0
