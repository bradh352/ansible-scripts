#!/bin/bash
# Script to auto-update wordpress for {{ wordpress_domain }} at {{ wordpress_install_path }}

# If any command in a chained pipe returns failure, count it as a failure
set -o pipefail

export PATH="$PATH:/usr/bin:/bin:/usr/local/bin"

# we have hardening settings that cause issues, so we have a php-cli-specific config dir
export PHP_INI_SCAN_DIR=/etc/php-cli.d/

DOMAIN="{{ wordpress_domain }}"
SITE_PATH="{{ wordpress_install_path }}"

WP=/usr/local/bin/wp

log() {
	logger -t wpupdate -p cron.notice "$*"
}

log_pipe() {
	{ sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\r//g' || true; } | logger -t wpupdate -p cron.notice
}

die() {
	log "$*"
	echo "$*"
	exit 1
}

log "Checking for update of ${DOMAIN} at ${SITE_PATH}"

cd "${SITE_PATH}" || die "unable to cd to ${SITE_PATH}"

log " * Updating Core"
${WP} core update --path="${SITE_PATH}" --no-color --skip-plugins --skip-themes | log_pipe || die "failed to update core"

log " * Updating DB"
${WP} core update-db --path="${SITE_PATH}" --no-color --skip-plugins --skip-themes | log_pipe || die "failed to update db"

log " * Updating plugins"
${WP} plugin update --all --path="${SITE_PATH}" --no-color --skip-plugins --skip-themes | log_pipe || die "failed to update plugins"

log " * Fixing perms"
chown -R apache:apache "${SITE_PATH}" || die "failed to fix perms"
restorecon -Rv "${SITE_PATH}" || die "failed to fix selinux perms"

log "DONE"
exit 0
