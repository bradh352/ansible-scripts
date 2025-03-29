# MariaDB Role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-scripts/tree/master/roles/service_mariadb

## Overview

This role is designed to deploy MariaDB.  This role supports both clustered and
non-clustered environments.  This does not yet support replication.

This role is initially targeting Rocky 9 and Ubuntu 24.04LTS, but other systems
such as RHEL derivatives and Debian derivatives may work, just not tested.

## Variables used by this role
* `mariadb_boostrap`: Boolean. Specific to MariaDB clusters. Must only be
  specified on the command line (e.g. `-e mariadb_bootstrap=true`).  Used to
  either bring up the first node in a cluster during initial creating or
  when recovering from a failure or shutdown of `all` nodes.  In failure
  situations may need to evaluate `grastate.dat` to determine the most advanced
  node and start that one as per https://mariadb.com/kb/en/getting-started-with-mariadb-galera-cluster/#restarting-the-cluster
* `mariadb_root_password`: MariaDB root password.  This is a security-sensitive
  password that should be stored in a vault.
* `mariadb_cluster`: Boolean. Whether or not this node is a member of a cluster.
* `mariadb_external_access`: Boolean. Whether or not to listen for external
  connections.  Ignored if `mariadb_cluster` is true as external connections
  are always allowed for clusters.
* `mariadb_sst_user`: Required if `mariadb_cluster` is true.  This is the
  username to use for database syncronization.  This user will automatically
  be created with the appropriate permissions and is only accessible via
  localhost.  This is a security-sensitive user and its password should be
  stored in a vault.
* `mariadb_sst_password`: Required if `mariadb_cluster` is true.  This is the
  password for `mariadb_sst_user`.
* `mariadb_clustercheck_user`: Required if `mariadb_cluster` is true.  This
  is the username to use for checking if the cluster node is online and ready
  to receive requests.  This user will automatically be created with the
  very minimal permissions and is only accessible via localhost.  This is
  not considered a security-sensitive user due to the minimal level of
  permissions.
* `mariadb_clustercheck_password`: Required if `mariadb_cluster` is true.  This
  is the password for `mariadb_clustercheck_user`.
* `mariadb_cluster_name`: Required if `mariadb_cluster` is true.  This is a
  simple alpha-numeric name for the cluster to differentiate it from other
  clusters.  This is also used by Ansible for grouping purposes.
* `mariadb_cluster_ip`: Required if using `mariadb_cluster`. The cluster ip address
  to use for cluster communication.  This is required as a host may have multiple
  IP addresses.
* `mariadb_cluster_singlewriter`: Boolean. When running in a cluster, some applications
  may use features that expect only a single node accept writes.  When this is
  true setting this flag will optimize for that environment.


## Groups used by this role

* `mariadb_{{ mariadb_cluster_name }}`: This group should reference all members
  associated with the same mariadb cluster.
