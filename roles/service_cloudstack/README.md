# CloudStack role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-scripts/tree/master/roles/service_ceph

## Overview

This role is designed to deploy CloudStack management and kvm hypervisor nodes.

This role is initially targeting Ubuntu, and tested on 24.04LTS.

## Core variables used by this role

***NOTE***: The cloudstack database is always named `cloud` and the usage
database is always `cloud_usage`.  There is no ability to change these.

- mariadb_root_password
- cloudstack_db_user - defaults to 'cloudstack'
- cloudstack_db_password
- cloudstack_mgmt_key - encryption key used to store credentials in the Cloudstack properties file. Use text string like password.
- cloudstack_db_key - encryption key used to store credentials in the Cloudstack database. Use text string like password.

