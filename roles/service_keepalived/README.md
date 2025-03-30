# Keepalived Role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-scripts/tree/master/roles/service_keepalived

## Overview

This role is designed to deploy Keepalived. Keepalived supports VRRP
(Virtual Router Redundancy Protocol) which allows for creation of Virtual IP
addresses.  This can be used for assigning a floating IP address to multiple
servers hosting a service and it will automatically choose a single server
out of the group to advertise the ip.  This uses health check scripts to
monitor the service on the local machine to determine if it is eligible to
advertise the IP.

Keepalived also supports LVS (Linux Virtual Server) which can be used for
server load balancing at layer 3/4 instead of using a proxy like HAProxy. This
feature is not currently implemented in this role but will likely be added
in the future.

## Variables used by this role

* `keepalived_vips`.  This is a top-level list containing all the virtual ips
  configured.  Under this list are dictionaries describing the virtual ip
  and monitoring.  In most cases there will be only a single VIP per system,
  but other use cases do exist such as when using on a shared loadbalancer
  that is balancing for multiple services.
  * `name`: Required. Simple name for service.  Should only contain alphanumerics
    and underscores. No spaces are allowed.
  * `interface`: Required. Network interface name on system that the virtual
    ip address(es) will be assigned to. e.g. `eth0`
  * `vrrp_interface`: Optional.  If the vrrp packets should be on a different
    network interface than where the virtual ip is assigned, then this can be
    specified.  By default uses the value from `interface`.
  * `priority_host`: Optional. If there is a reason that a specific host in
    the VRRP group should be used if online rather than picking a random host,
    provide its ansible inventory hostname here and it will be preferred.
  * `ips`: Required. List of IP addresses with subnet mask to assign to
    `interface`. E.g. `10.10.10.100/24`
  * `healthcheck`: Required, contains rules for monitoring the service.
    * `type`: Type of healthcheck, allowed values are `ip`, `tls`, and `script`.
      Each option takes one or more arguments.
    * `timeout`: How long to wait on the healthcheck to complete. Default `10` seconds.
    * `interval`: How often to run the healthcheck. Default `15` seconds.
    * `host`: Optional if `type` is `ip` or `tls`.  This is the hostname or ip
      to use to query the service.  Typically not used.  Defaults to `localhost`.
    * `port`: Required if `type` is `ip` or `tls`.  This is the port of the
      service to connect to.
    * `fqdn`: Optional if `type` is `tls`.  This is the SNI TLS Hostname to use
      for the check.  This is often the external name and is used by the host
      for looking up the proper TLS certificate to advertise.  If not provided
      uses `host` (or its default value).
    * `verify_certs`: Optional if `type` is `tls`. This is a boolean value and
      if true will fail the health check if TLS certificate validation is not
      successful. Default is `false`.
    * `script`: Required if `type=script`. This is the full path to the script to
      run as the healthcheck.
    * `script_arg`: Optional if `type=script`. This is an argument to pass to
      the user-specified script.

## Example Config

```
keepalived_vips:
  - name: "mariadb"
    interface: "eth0"
    ips:
      - 192.168.1.10/24
      - 2620:1234:5::10/64
    healthcheck:
      type: "ip"
      port: 3306
```
