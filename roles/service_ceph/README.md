# Ceph Role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-scripts/tree/master/roles/service_ceph

## Overview

This role is designed to deploy Ceph in a non-containerized environment.  It can
deploy Monitors, MDS, and OSDs and is targeting Hyperconvered deployments.

This role is initially targeting Ubuntu, and tested on 24.04LTS.

## Core variables used by this role
* `ceph_cluster_name`: This name is used as an organization tool in Ansible.
  There are groups (specified in the next section) that are used to identify
  what services are deployed on each node in the cluster, and this name is
  used to reference the correct group.  This name may contain alphanumerics
  and underscores only.  This does not attempt to change the cluster name of the
  installed ceph instance, which is always "ceph" as unique cluster names are
  deprecated as per:
  https://docs.ceph.com/en/latest/rados/configuration/common/#naming-clusters-deprecated
* `ceph_public_network`: The ipv4 subnet to use for public client communication.
  This is the network where ceph clients talk to the ceph backend.  This may
  be the same as `ceph_cluster_network`.  This should be a group var for the
  cluster.
* `ceph_cluster_network`: The ipv4 subnet to use for cluster communication. This
  is the network where ceph OSDs communication with eachother for syncronization
  tasks.  This may be the same as `ceph_public_network`.  This should be a group
  var for the cluster.
* `ceph_uuid`: A unique UUID to reference the cluster.  Use `uuidgen` to
  generate this value.  This should be a group var for the cluster.
 `ceph_mon_ip`: Must be unique for each monitor node in the cluster.  This
  is a node-specific value.
* `ceph_osd_room`: Optional. Short alphanumeric (no spaces) name of the room in
  which the ceph host resides.  Specifying this will place the OSD in this
  bucket to assist in determining the proper failure domains.
* `ceph_osd_row`: Optional. Short alphanumeric (no spaces) name of the row in
  which the ceph host resides.  Specifying this will place the OSD in this
  bucket to assist in determining the proper failure domains.
* `ceph_osd_rack`: Optional. Short alphanumeric (no spaces) name of the rack in
  which the ceph host resides.  Specifying this will place the OSD in this
  bucket to assist in determining the proper failure domains.
* `ceph_osd_chassis`: Optional. Short alphanumeric (no spaces) name of the
  chassis (such as when hosts share a single chassis, e.g. Supermicro microcloud)
  in which the ceph host resides.  Specifying this will place the OSD in this
  bucket to assist in determining the proper failure domains.

### Variables for configuring resources

* `ceph_pools`: List of ceph pools to create.  If a ceph pool by the same name
  already exists, it will not be modified with the possible settings.  It is
  up to the user to correct any settings post-creation.  Pools created here are
  always configured to be used as `rbd` pools.  The autoscaler is also automatically
  enabled.  Does not currently support creating erasure coded pools.
  See `ceph_fs`, which will create its own pools for CephFS.
  * `name`: Name of the ceph pool.  Can contain alpha-numerics, hypens, periods,
    and underscores (`[A-Za-z0-9_.-]`).
  * `replica`: Number of replicas for the data.  Defaults to `3`.
  * `min_size`: Minimum number of replicas online before the pool goes offline.
    Recommended to be at least `2`.
  * `bulk`: Whether or not the pool is expected to be large (contain a lot of
    data).  Defaults to `true`.

* `ceph_fs`

## Groups used by this role

NOTE: When `ceph_cluster_name` is specified below, all hyphens (`-`) will be
      replaced with underscores (`_`) to comply with group name requirements.
* `ceph_{{ ceph_cluster_name }}_mon`: All members of this group will deploy
   monitors.  If this is the first monitor being deployed, `ceph_bootstrap=true`
   must be specified on the command line.
* `ceph_{{ ceph_cluster_name }}_mds`: All members of this group will deploy
   mds daemons.
* `ceph_{{ ceph_cluster_name}}_osd`: All members of this group will deploy
   OSDs. Disks available on the host will automatically be created as OSDs
   as long as they are non-removable, do not currently contain a partition
   table, and are at least 1TB in size.


