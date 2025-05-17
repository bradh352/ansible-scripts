# Base OS Setup Role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-scripts/tree/master/roles/base

## Overview

This role is used to configure a Linux host with some minimum requirements 
common to all systems, including hardening as per CIS and PCI-DSS standards.

## Variables used by this role

- `superuser` - Name of the superuser to ensure exists on a system. Required.
- `superuser_password` - Password for the superuser.  Should be stored in a
  vault. Required.
- `superuser_pubkey` - list of SSH public keys to associated with the superuser
  account. Optional.
- `timezone` - Validate timezone such as `America/New_York`, `US/Eastern`, or `UTC`
  as can be seen as paths in `/usr/share/zoneinfo/`. Defaults to `UTC`.
- `admin_email` - Email address to use for notifications, such as cron task
  failures. Required.
- `smtp_server` - SMTP server to use to send emails through. Required.
- `ssh_port` - Port to listen for inbound SSH connections. Defaults to 22.
- `ssh_password_auth` - Whether or not to allow password authentication.
  Default `false`.  Recommended to use SSH public keys or GSSAPI.
- `os_autoupdate` - Whether to allow the OS to perform automatic updates.
  Defaults to `false`.
- `skip_updates` - This role automatically attempts to upgrade all packages to
  their latest versions.  May specify `-e skip_updates=true` on the command line
  to bypass this behavior.
- `ntp_pools` - List of NTP pools. Defaults to
  `["0.us.pool.ntp.org", "1.us.pool.ntp.org", "2.us.pool.ntp.org", "3.us.pool.ntp.org"]`
- `ntp_peers` - If running multiple internal NTP servers, these can be the ones to
  peer with. Default none.
- `grub_password` - This is a hashed password used by Grub for making changes
  via the grub menu.  It must be generated via:
  `grub2-mkpasswd-pbkdf2` (RedHat) or `grub-mkpasswd-pbkdf2` (Debian)
  We can't do this dynamically because of the random salt, so it is no longer
  idempotent.  So we cache it here.  Should be updated whenever
  `superuser_password` is updated if using the same password.  Likely this should
  also be stored in the vault even though it is hashed.

## Initial deployment

Since the username and password used to log into a machine may not be the same
as gets used once this playbook runs, these additional command line
`ansible-playbook` variables may need to be specified:
```
-e ansible_user=infra -e ansible_password="Test123$" -e ansible_become_password="Test123$"
```
 * NOTE: do not use `ansible_become_pass` as that isn't able to be overwriten
   internally by the playbook as part of the process of changing authentication
   during the deployment.
