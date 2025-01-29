[![SONiC](https://sonicfoundation.dev/wp-content/uploads/sites/21/2023/04/logo.svg)](https://sonicfoundation.dev/)

# SONiC Ansible Role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-scripts/tree/master/roles/sonic

- [Overview](#overview)
- [Implementation Details](#implementation-details)
- [Tested On](#tested-on)
- [Variables used by this role](#variables-used-by-this-role)
  - [Example Config](#example-config)
  - [Spine vs Leaf](#spine-vs-leaf)
- [Useful SONiC commands / information](#useful-sonic-commands--information)
  - [Default username and password](#default-username-and-password)
  - [Restore to factory-default configuration](#restore-to-factory-default-configuration)
  - [Installing a different SONiC Image via SONiC](#installing-a-different-sonic-image-via-sonic)
  - [Bootstrap / Ansible](#bootstrap--ansible)
  - [VXLAN verification](#vxlan-verification)
  - [BGP](#bgp)
    - [View Neighbors](#view-neighbors)
    - [View IPv4 Routes](#view-ipv4-routes)
    - [View EVPN routes](#view-evpn-routes)
    - [Debugging](#debugging)

## Overview
This is an ansible role to configure an installation of SONiC, it
is designed to work on any switch supported by SONiC.  While it is recommended
to use this against a fresh install, in theory it should be able to operate
against an already configured installation.

This role is designed to be idempotent and encapsulate the ***complete***
configuration of the switch.  It is not meant to perform a manual update of a
single setting, instead it reads in the variables which represent the
entirety of the switch configuration and applies the diff of the configuration
from the current state.  It is expected most changes to the configuration
variables in this role can be completed without any sort of outage (other than
the obvious reasons, like you disabled the port you're using to connect to the
switch and configure it).

In some circumstances this may detect the configuration change is too large
and require a reboot; this is true on a fresh installation, and likely if
the switch was configured external to this role, but generally not expected to
be needed if previously configured with this role.

SONiC supported switches are listed here:
https://sonic-net.github.io/SONiC/Supported-Devices-and-Platforms.html
However not all switches on that list support all features you may expect,
nor are necessarily stable.  For instance, Broadcom Trident3-x3 (aka Helix5)
switches are unstable and also do not support VXLAN (even though the ASIC
supports the feature, Broadcom has decided not to include support in their
community SAI release).  Also Broadcom Tomahawk ASICs prior to v4 do not support
VXLAN, and Trident 2 switches and below also do not support VXLAN.

The latest downloads are made available here (the prior link does list some
downloads but may not be the best option):
https://sonic.software/

***NOTE***: Stock SONiC has bugs.  I'm currently maintaining a fork with
some backports [here](https://github.com/bradh352/sonic-buildimage)

Features currently supported by this role are:
 * BGP unnumbered
 * VXLAN EVPN using BGP unnumbered
 * VLAN assignments
 * IP Address assignments
 * Static Routes
 * PortChannel

***Not*** currently supported (but will likely be in the future):
 * MLAG/MCLAG
 * Port Break-out
 * Configuring auxiliary services (e.g. NTP, SNMP, Syslog)
 * Configuring Authentication
   * Local Passwords / SSH Keys
   * RADIUS
 * SpanningTree (which in theory is not needed in VXLAN environments)


## Implementation Details

The documentation used for generating the SONiC config is here:
https://github.com/sonic-net/sonic-buildimage/blob/master/src/sonic-yang-models/doc/Configuration.md
(however this document is incomplete and it is recommended to look at the
actual yang models themselves for a complete listing of options).  In theory
someone using this shouldn't need to reference these docs.

This role reads in the configuration on the device, then modifies it by
overwriting various sections, and writing it back.  We then, internally, use the
`config replace` command which merges our updates into the running config.  This
was chosen over the `config reload` command, which instead of merging changes
performs a hard reset of the entire configuration.

This role manages the BGP configuration via the FRR config directly.  Though
SONiC does have some built-in capabilities for managing BGP, it doesn't appear
it is yet capable of supporting BGP Unnumbered with VXLAN EVPN support.

## Tested On

This has been tested on [Dell S5248F](https://www.dell.com/en-us/shop/ipovw/networking-s-series-25-100gbe)
and [Nvidia/Mellanox SN2201](https://resources.nvidia.com/en-us-accelerated-networking-resource-library/ethernet-switches-ne).
Attempting testing on [Dell N3248TE](https://www.dell.com/en-us/shop/ipovw/networking-n3200-series) was
ultimately unsuccessful due to the 2 issues mentioned above with Trident3-x3 systems.

These switches were bought off ebay, with the 2 Dell switches being ~$1100USD
and ~$700USD respectively.  And the Mellanox switch going for considerably more
at ~$2000USD.  They have been and loaded with the SONiC image fork I'm
maintaining.

I'd imagine Dell's Enterprise SONiC would work as advertised on the Trident3-x3
based switch as it is explicitly developed by Dell and Broadcom and includes
the Enterprise SAI.

## Variables used by this role

***Important***: please pay attention to whether a variable takes an array
vs a dictionary.  A dictionary entry will **NOT** have a leading `-` and its
members will be indented, while an array **will** have a leading `-` but its
members will be at the same indention level.  For example, `sonic_interfaces`
and `sonic_vlans` take dictionaries, but `sonic_routes` and the `vlans` member
of `sonic_interfaces` takes an array.  Design decisions were made for ease of
processing the variables based on how SONiC is configured. See the example
config if still confused.

* `sonic_vxlan_vtep_ip`: IPv4 Address with subnet mask to use for running BGP
  for the VXLAN VTEP.  This will set up a Loopback Interface with the address
  and also be configured as the router id and VXLAN vtep source IP address.
  Example: `10.1.0.1/32`
* `sonic_asn`: Autonomous system number to use.  Should be unique per host and
  should be allocated in the private use range. Example: `4210000001`
* `sonic_interfaces`: Dictionary of the interface configurations.  The key
  is the interface index (as enumerated on the front panel of the switch).  The
  value is also a dictionary with these keys:
  * `admin_status`: `up`/`down`. Whether the interface is administratively
    enabled.  Default is `up` if the interface is defined in this dictionary,
    otherwise `down`.
  * `autoneg`: `on`/`off`. Whether the interface should enable autonegotiation.
    Defaults to `on` if there is no SFP and the system max port speed is 10000
    or less, or if we determine the port is RJ45.  Otherwise `off`.
  * `adv_speeds`: Comma delimited list of speeds in Megabits per second to
    advertise if autonegotiation is enabled. Example: `10000,1000,100`.  By
    default it will use whatever the interface is capable of.
  * `speed`: Interface speed in Megabits per second. Defaults to the maximum
    port speed. Most SFP modules won't come up if the speed is wrong.
    Example: `25000` (25G)
  * `description`: User-provided description of the interface for convenience.
    Typically describes what is plugged into the port.  Default is "".
  * `fec`: Forward error correction.  `rs`,`fc`,`auto`,`none`. Defaults to
    `none` if port speed is less than 25000 or autonegotiation is on otherwise
    `rs`.
  * `layer3`: `true`/`false`. Whether this interface will be used as a layer3
    interface.  Currently this just enables ipv6 link local addresses on the
    interface and allows other config options to be used (like `mtu` even if no
    ip addresses are set). Default is `false`.
  * `bgp_underlay`: `true/false`. Whether this interface is part of the bgp
    underlay network using BGP Unnumbered.  Requires `layer3` set to `true`.
    Default is `false`.
  * `vrf`: Name of the VRF to assign the interface to. Always starts with `Vrf`.
  * `mac_addr`: MAC address of the interface.  Only relevant for routed
    interfaces (e.g. those with `ips` or `layer3` set).  If not specified, will
    generate a random mac for the interface.
  * `mtu`: The MTU of the interface. If not provided, defaults to `9216` on
    routed ports (typically used as underlay), and `9100` on trunk and access
    ports.  Must not be specified under `sonic_interfaces` if the port is a
    member of a PortChannel.
  * `ips`: Array of ipv4 and/or ipv6 addresses with subnet mask to assign to the
    interface.  Cannot be used with `vlans` (you should probably create a vlan
    with an ip address list instead). Example:
    `[ "1.2.3.4/24", "2620:3:4:5::6/64" ]`
  * `vlans`: Vlans to assign to an interface. The vlan must have been already
    created using the `sonic_vlans` configuration. Cannot be used with `ips`,
    or `layer3`. The value is an array of dictionaries with these keys:
    * `vlan`: Vlan id to use (1-4096), required.
    * `mode`: `tagged`/`untagged`. Only a single vlan may be marked as untagged
      for a single interface.
* `sonic_vlans`: Dictionary of the VLAN/VXLAN configuration. For each vlan
  specified in an interface, an entry must exist here.  The key is the
  VLAN id.  The value is also a dictionary with these keys:
  * `vxlan`: If mapping a VXLAN to a VLAN, this is the VXLAN id. Valid range
    is 1-16777214.  This is necessary if you want to be able to forward a
    vxlan to a connected device that is not participating in the VXLAN-EVPN.
  * `ips`: Array of ipv4 and/or ipv6 addresses with subnet mask to assign to the
    vlan virtual interface. Example: `[ "1.2.3.4/24", "2620:3:4:5::6/64" ]`
  * `layer3`: `true`/`false`. Whether this interface will be used as a layer3
    interface.  This enables IPv6 link-local address support. Default is
    `false`.
  * `mtu`: MTU to use for vlan.  Defaults to `1500` for routed vlans (is
     layer3 or has ips), and `9100` for non-routed.  Remember when using VXLANs
     there is a 50 byte overhead so make sure the interface MTU is greater than
     this value.
  * `vrf`: Name of the VRF to assign the interface to. Always starts with `Vrf`.
* `sonic_portchannel`: Dictionary of the portchannel configurations.  The key
  is the portchannel id.  This is a number between 1 and 9999.  The value is
  also a dictionary with these keys (most are duplicative from
  `sonic_interfaces`):
  * `interfaces`: Array of interface indexes (as enumerated on the front panel
    of the switch, same as `sonic_interfaces` members).  Any specified interface
    must not have `layer3`, `vlans`, `macaddr`, or `ips` set.
  * `description`: see definition in `sonic_interfaces`.
  * `layer3`: see definition in `sonic_interfaces`.
  * `mtu`: see definition in `sonic_interfaces`.
  * `admin_status`: see definition in `sonic_interfaces`.
  * `mac_addr`: see definition in `sonic_interfaces`.
  * `ips`: see definition in `sonic_interfaces`.
  * `vlans`: see definition in `sonic_interfaces`.
  * `vrf`: see definition in `sonic_interfaces`.
* `sonic_routes`: Array of dictionaries used to configure static routes.  The
  keys for the dictionary are:
  * `prefix`: IPv4 or IPv6 prefix, Example: `192.168.1.0/24`.  For a default
     gateway use `0.0.0.0/0` for ipv4 and `::/0` for ipv6. Required.
  * `nexthop`: The ip address of the next hop.  If not specified, must specify
    `ifname`.
  * `ifname`: The interface name for the next hop.  If not specified, must
    specify `nexthop`.


***NOTE***: Typically variables will be placed in the host vars, it is
recommended to create a file like `host_vars/switch-fqdn.yml` that contains
these settings.

### Example Config

```
sonic_bgp_ip: "172.16.0.1/32"
sonic_asn: "4210000001"
sonic_interfaces:
  "1":
    layer3: true
    admin_status: "up"
    description: "CloudStack Node 1"
  "9":
    admin_status: "up"
    description: "upstream port for internet access"
    vlans:
      - vlan: 2
        mode: "untagged"
  "10":
    description: "some machine on an access port in vlan 10"
    admin_status: "up"
    vlans:
      - vlan: 10
        mode: "untagged"
  "11":
    description: "Some machine on vlan 2 and 10"
    admin_status: "up"
    vlans:
      - vlan: 2
        mode: "tagged"
      - vlan: 10
        mode: "tagged"
  "55":
    layer3: true
    admin_status: "up"
    description: "ToRSwitch 2 port 55"
  "56":
    layer3: true
    admin_status: "up"
    description: "ToRSwitch 2 port 56"
sonic_vlans:
  "2":
    ips:
      - "10.0.0.71/24"
    vxlan: "10002"
    layer3: true
  "10":
sonic_routes:
  - prefix: "0.0.0.0/0"
    next_hop: "10.0.0.1/24"
```

### Spine vs Leaf

This role doesn't differentiate between Spine and Leaf deployments.  In general
a Spine deployment will simply share the **same** ASN rather than using a
unique ASN per node.  This does, however, require that every spine connects to
every leaf which ensures a packet at most flows through two switches East-West.
In a spine/leaf architecture, spines also do not iBGP peer with eachother like
you would typically do when sharing the same ASN.

That said, the described classic architecture (which is well accepted) seems
to allow well-placed link failures to inhibit East-West traffic flows.

Alternatively if you deploy Spines using the same methodology as a leaf by
using unique ASNs for all nodes, and also allow Spines to peer with eachother,
this would seem to mitigate any such scenarios.  The documented downsides
would be excess load due to route/FIB changes (which can be mitigated by
capping the number of paths that can be installed) as well as the increased
packet flows which **in theory** might be able to cascade into a larger outage.
This may also cause unpredictable traffic patterns or hurt observability.

As always, its up to the network admins to evaluate their specific situation,
traffic flows, and risk associated with the chosen implementation method.

## Useful SONiC commands / information

### Default username and password
Factory default configuration uses:
* username: admin
* password: `YourPaSsWoRd`

`sudo` is passwordless.

### Restore to factory-default configuration
Generate a new configuration:
```
sudo rm /etc/sonic/config_db.json
sudo config-setup factory
```

Then to apply it, you might issue a reload:
```
sudo config reload -f -y
```

However, in some circumstances it doesn't fully reset I've found.  It may be
better to:
```
sudo reboot
```

### Installing a different SONiC Image via SONiC
```
sonic-installer install https://...
```

### Issues / Fixes
* https://github.com/sonic-net/sonic-buildimage/issues?q=is%3Apr+author%3Abradh352
* https://github.com/sonic-net/sonic-swss/issues?q=is%3Apr+author%3Abradh352
* https://github.com/sonic-net/sonic-utilities/issues?q=is%3Apr+author%3Abradh352
* https://github.com/sonic-net/sonic-platform-daemons/issues?q=is%3Apr+author%3Abradh352

### Bootstrap / Ansible

When bootstrapping a switch, plug the dedicated MGMT port (typically `eth0`)
into a network that will assign it a DHCP address.  Use the console port to log
into the switch to determine the ip address (`ip address show dev eth0`).

Make sure you've added a host in your Ansible inventory and set the appropriate
host vars representing the switch configuration.

Assuming the inventory name is `sw1.testenv.bradhouse.dev`, you can pass
parameters on the command line to connect to this temporary ip address with
initial username and password:
```
ansible-playbook -v playbook.yml --limit sw1.testenv.bradhouse.dev -e ansible_user=admin -e ansible_password=YourPaSsWoRd -e ansible_host=192.168.1.196
```

Typically after the initial run, the management port should be unplugged or
disabled on the upstream switch and only used during recovery operations.  It
is best practice for your switch configuration to create an IRB (VLAN) interface
with IP address in your network's management vlan.

### VXLAN verification
In this example we have 2 switches with VTEP (vxlan evpn endpoint) ipv4
addresses of 172.16.0.1/32 (local) and 172.16.0.2/32 (remote) that are using
BGP unnumbered to exchange routes.  This means that all we need to know is about
our local ip and it will auto-discover and exchange routes and vxlan vteps
without configuring each one.  We also created a Vlan2 mapped to vxlan
VNI 10002 on both switches and assigned ipv4 addresses of 10.0.0.71 (local)
and 10.0.0.72 (remote).  The end goal is to be able to ping 10.0.0.72 from
10.0.0.71 traversing the vxlan evpn tunnel.

### Make sure we configured the VXLAN and VLAN mapping correctly
```
# show vxlan interface
VTEP Information:

  VTEP Name : vtep, SIP  : 172.16.0.1
  NVO Name  : nvo,  VTEP : vtep
  Source interface  : Loopback0
```

```
# show vxlan vlanvnimap
+--------+-------+
| VLAN   |   VNI |
+========+=======+
| Vlan2  | 10002 |
+--------+-------+
Total count : 1
```

```
# show vxlan tunnel
vxlan tunnel name    source ip    destination ip    tunnel map name    tunnel map mapping(vni -> vlan)
-------------------  -----------  ----------------  -----------------  ---------------------------------
vtep                 172.16.0.1                     map_10002_Vlan2    10002 -> Vlan2
```
  * I'm assuming destination IP is blank since we're doing EVPN and there would be multiple endpoints


### Verify it learned about our peer
```
# show vxlan remotevtep
+------------+------------+-------------------+--------------+
| SIP        | DIP        | Creation Source   | OperStatus   |
+============+============+===================+==============+
| 172.16.0.1 | 172.16.0.2 | EVPN              | oper_down    |
+------------+------------+-------------------+--------------+
Total count : 1
```
 * oper_down is wrong here, there's a PR for that: https://github.com/sonic-net/sonic-swss/pull/2080


```
# vtysh -c "show evpn vni detail"
VNI: 10002
 Type: L2
 Tenant VRF: default
 VxLAN interface: vtep-2
 VxLAN ifIndex: 10
 SVI interface: Vlan2
 SVI ifIndex: 9
 Local VTEP IP: 172.16.0.1
 Mcast group: 0.0.0.0
 Remote VTEPs for this VNI:
  172.16.0.2 flood: HER
 Number of MACs (local and remote) known for this VNI: 2
 Number of ARPs (IPv4 and IPv6, local and remote) known for this VNI: 4
 Advertise-gw-macip: No
 Advertise-svi-macip: No
```

### Verify if it learned EVPN type-2 (IP/MAC)

```
# vtysh -c "show bgp l2vpn evpn"
BGP table version is 3, local router ID is 172.16.0.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
Origin codes: i - IGP, e - EGP, ? - incomplete
EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

   Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 172.16.0.1:2
 *> [2]:[0]:[48]:[26:44:26:54:43:d9]:[32]:[10.0.0.71]
                    172.16.0.1                         32768 i
                    ET:8 RT:32897:10002
 *> [2]:[0]:[48]:[26:44:26:54:43:d9]:[128]:[fe80::2444:26ff:fe54:43d9]
                    172.16.0.1                         32768 i
                    ET:8 RT:32897:10002
 *> [3]:[0]:[32]:[172.16.0.1]
                    172.16.0.1                         32768 i
                    ET:8 RT:32897:10002
Route Distinguisher: 172.16.0.2:2
 *> [2]:[0]:[48]:[e2:13:0d:e6:a0:bb]:[32]:[10.0.0.72]
                    172.16.0.2                             0 4210000002 i
                    RT:32898:10002 ET:8
 *> [2]:[0]:[48]:[e2:13:0d:e6:a0:bb]:[128]:[fe80::e013:dff:fee6:a0bb]
                    172.16.0.2                             0 4210000002 i
                    RT:32898:10002 ET:8
 *> [3]:[0]:[32]:[172.16.0.2]
                    172.16.0.2                             0 4210000002 i
                    RT:32898:10002 ET:8

Displayed 6 out of 6 total prefixes
```
 * Note the 10.0.0.71 / 10.0.0.72, and type-2 routes


```
# show vxlan remotemac all
+--------+-------------------+--------------+-------+---------+
| VLAN   | MAC               | RemoteVTEP   |   VNI | Type    |
+========+===================+==============+=======+=========+
| Vlan2  | e2:13:0d:e6:a0:bb | 172.16.0.2   | 10002 | dynamic |
+--------+-------------------+--------------+-------+---------+
Total count : 1
```

```
# ip neigh
192.168.1.1 dev eth0 lladdr e0:63:da:2f:a6:38 REACHABLE
10.0.0.72 dev Vlan2 lladdr e2:13:0d:e6:a0:bb extern_learn NOARP proto zebra
192.168.1.198 dev eth0 FAILED
169.254.0.1 dev Ethernet54 lladdr e2:13:0d:e6:a0:bb PERMANENT proto zebra
192.168.1.212 dev eth0 lladdr aa:e7:61:a6:c6:b6 REACHABLE
192.168.1.232 dev eth0 lladdr 74:86:e2:43:28:05 REACHABLE
fe80::e263:daff:fe2f:a638 dev eth0 lladdr e0:63:da:2f:a6:38 router STALE
fe80::e013:dff:fee6:a0bb dev Ethernet54 lladdr e2:13:0d:e6:a0:bb router REACHABLE
fe80::e013:dff:fee6:a0bb dev Vlan2 lladdr e2:13:0d:e6:a0:bb extern_learn NOARP proto zebra
fe80::1a5a:58ff:fe2a:e820 dev eth0 lladdr 18:5a:58:2a:e8:20 router REACHABLE
```
 * See the remote 10.0.0.72 here


### See if it works
```
# ip address show dev Vlan2
9: Vlan2@Bridge: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9100 qdisc noqueue state UP group default qlen 1000
    link/ether 26:44:26:54:43:d9 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.71/24 brd 10.0.0.255 scope global Vlan2
       valid_lft forever preferred_lft forever
    inet6 fe80::2444:26ff:fe54:43d9/64 scope link
       valid_lft forever preferred_lft forever
```

```
# ping 10.0.0.72
PING 10.0.0.72 (10.0.0.72) 56(84) bytes of data.
64 bytes from 10.0.0.72: icmp_seq=1 ttl=64 time=0.337 ms
64 bytes from 10.0.0.72: icmp_seq=2 ttl=64 time=0.278 ms
64 bytes from 10.0.0.72: icmp_seq=3 ttl=64 time=0.325 ms
64 bytes from 10.0.0.72: icmp_seq=4 ttl=64 time=0.319 ms
^C
--- 10.0.0.72 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3072ms
rtt min/avg/max/mdev = 0.278/0.314/0.337/0.022 ms

```

Success!

### BGP

#### View Neighbors
Summary:
```
vtysh -c "show ip bgp summary"
```

Detail:
```
vtysh -c "show bgp neighbor"
```

#### View IPv4 Routes
```
vtysh -c "show ip bgp"
```

#### Show advertised routes
```
vtysh -c "show ip bgp neighbors Ethernet54 advertised-routes"
```

#### View EVPN routes
```
vtysh -c "show bgp l2vpn evpn route"
```

#### Debugging
Log into BGP container:
```
sudo docker exec -it bgp /bin/bash
```

Check configuration:
```
/usr/lib/frr/bgpd -C
```

