# Network VXLAN-EVPN Role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-scripts/tree/master/roles/network_vxlanevpn

## Overview

This role is used to configure a Linux host to participate in a pure Layer3
VXLAN EVPN network.  The underlay is provisioned using BGP Unnumbered
(using only link-local ip addresses).  The BGP stack in use is FRR.

It is strongly recommended to use a network card that supports VXLAN offloading
such as Mellanox/Nvidia Connect-X4 or better.

This role is initially targeting Ubuntu, and tested on 24.04LTS.

## Variables used by this role

* `network_vtep_ip`: Required. IPv4 address and subnet used by the underlay
  network for VXLAN tunnel endpoints.  This IP address is exchanged using
  BGP Unnumbered to facilitate communication, it must be unique across the
  underlay.  A subnet mask must be specified for the firewall to know what
  address ranges are allowed, however only a `/32` will be advertised.
  e.g. `172.17.0.2/24`
* `network_underlay_asn`: Required. Autonomous System Number to use for the
   underlay. This should be unique across the underly.  The private ASN range
   is `64512` to `65534` and `4200000000` to `4294967294`.
* `network_underlay_interfaces`: Required. List of interfaces to use for the
  underlay network.  These are BGP unnumbered interfaces that cannot be used for
  any other purpose.  They must specify only ***one*** of the below options.
    * `ifname`: exact interface name, e.g. `ens1`, `enp7s0f0np0`
    * `pattern`: Regex pattern to match on interface name.  This can add more
      than one interface at a time. e.g. `ens.*`, `ens[23]`
    * `macaddr`: Mac address of interface
    * `driver`: Driver module to match on.  This can add more than one interface
      at a time.  e.g. `mlx5_core`, `ixgbe`
* `network_underlay_mtu`: MTU to use for all underlay interfaces.  Defaults
  to `9100` if not specified.  This must be at least 54 bytes greater than
  the largest `network_vxlan_interfaces` mtu.
* `network_vxlan_interfaces`: List of virtual vxlan interfaces to create and
  attach to the bridge.
  * `name`: Interface name to assign
  * `vni`: VXLAN vni (`1` to `16777215`)
  * `mtu`: MTU. Must be at least 54 bytes less than `network_underlay_mtu`.
    Defaults to `1500`.  Recommended `9000` for Jumbo Frames.
  * `dhcp`: Default `false`. Set to true to use dhcp.  Cannot be used with
    `addresses`.
  * `addresses`: List of ip (v4 or v6) addresses with subnet mask.  Cannot be
    used with `dhcp`.  e.g.: `10.23.45.2/24`, `2600:1234::2/64`
  * `routes`: List of routes.  If none specified will only be able to access
    other machines in the same subnet.
    * `to`: Subnet to add route for.  Use `0.0.0.0/0` or `::/0` for default
      route for ipv4 or ipv6, respectively.
    * `via`: Gateway to use to access specified subnet. e.g. `10.23.45.1` or
      `2600:1234::1`
  * `nameservers`: Dictionary of values for DNS configuration
    * `addresses`: List of addresses for nameservers,
      e.g. `8.8.8.8` or `2001:4860:4860::8888`
    * `search`: List of search domains, e.g. `internal.example.com`
* `network_interfaces`: These are interfaces which do not participate in the
  vxlan, perhaps for something like backdoor access.  Most deployments may
  not utilize this configuration at all. It uses the same format as
  `network_vxlan_interfaces` and requires the caller to know the interface
  name as it does not support pattern, macaddr, or driver matching.
  * `ifname`: Known system interface name
  * `mtu`: MTU. Defaults to `1500`.  Recommended `9000` for Jumbo Frames.
  * `dhcp`: Default `false`. Set to true to use dhcp.  Cannot be used with
    `addresses`.  **NOTE:** this will explicitly disable reception of routes
    and DNS servers and is only used for ip address assignment in this context
    due to the expectation that if DHCP is needed it will be part of the
    VXLAN network.
  * `addresses`: List of ip (v4 or v6) addresses with subnet mask.  Cannot be
    used with `dhcp`.  e.g.: `10.23.45.2/24`, `2600:1234::2/64`
  * `routes`: List of routes.  If none specified will only be able to access
    other machines in the same subnet.  Typically not used with `dhcp`.
    * `to`: Subnet to add route for.  Use `0.0.0.0/0` or `::/0` for default
      route for ipv4 or ipv6, respectively.
    * `via`: Gateway to use to access specified subnet. e.g. `10.23.45.1` or
      `2600:1234::1`
  * `nameservers`: Dictionary of values for DNS configuration. Typically not
    used with `dhcp`.
    * `addresses`: List of addresses for nameservers,
      e.g. `8.8.8.8` or `2001:4860:4860::8888`
    * `search`: List of search domains, e.g. `internal.example.com`

***NOTE***: Typically variables will be placed in the host vars, it is
recommended to create a file like `host_vars/host-fqdn.yml` that contains
these settings.

### Example
```
network_vtep_ip: "172.17.0.2"
network_underlay_asn: 4201000002
network_underlay_interfaces:
  - driver: "mlx5_core"
network_underlay_mtu: 9100
network_vxlan_interfaces:
  - name: "hypervisor"
    vni: 100
    mtu: 9000
    addresses:
      - "10.10.100.2/24"
      - "2620:1234:100::2/64"
  - name: "ceph"
    vni: 200
    mtu: 9000
    addresses:
      - "10.10.200.2/24"
      - "2620:1234:200::2/64"
  - name: "public"
    vni: 1
    mtu: 1500
    addresses:
      - "10.10.1.2/24"
      - "2620:1234:1::2/64"
    routes:
      - to: "0.0.0.0/0"
        via: "10.10.1.1"
      - to: "::/0"
        via: "2620:1234:1::1/64"
    nameservers:
      addresses:
        - 8.8.8.8
        - 2001:4860:4860::8888
      search:
        - "sn1.example.com"
        - "sn2.example.com"
network_interfaces:
  - ifname: "ens1"
    dhcp: "yes"
```

