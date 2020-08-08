#!/bin/bash
# Script to auto-update wordpress for {{ wordpress_domain }} at {{ wordpress_install_path }}

# exit on any failure
set -e

export PATH="$PATH:/usr/bin:/bin:/usr/local/bin"

# we have hardening settings that cause issues, so we have a php-cli-specific config dir
export PHP_INI_SCAN_DIR=/etc/php-cli.d/

DOMAIN="{{ wordpress_domain }}"
SITE_PATH="{{ wordpress_install_path }}"

echo "Checking for update of ${DOMAIN} at ${SITE_PATH}"

cd "${SITE_PATH}"

echo " * Updating Core"
/usr/local/bin/wp core update --path="${SITE_PATH}"
echo " * Updating DB"
/usr/local/bin/wp core update-db --path="${SITE_PATH}"
echo " * Updating plugins"
/usr/local/bin/wp plugin update --all --path="${SITE_PATH}"
echo " * Fixing perms"
chown -R apache:apache "${SITE_PATH}"
restorecon -Rv "${SITE_PATH}"
