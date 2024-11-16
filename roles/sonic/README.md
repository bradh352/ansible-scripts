[![SONiC](https://sonicfoundation.dev/wp-content/uploads/sites/21/2023/04/logo.svg)](https://sonicfoundation.dev/)

# SONiC Ansible Role

Author: Brad House<br/>
License: MIT<br/>
Original Repository: https://github.com/bradh352/ansible-scripts/tree/master/roles/sonic

- [Overview](#overview)
- [Tested On](#tested-on)
- [Variables used by this role](#variables-used-by-this-role)
  - [Example Config](#example-config)
- [Useful SONiC commands / information](#useful-sonic-commands--information)
  - [Default username and password](#default-username-and-password)
  - [Restore to factory-default configuration](#restore-to-factory-default-configuration)
  - [Bootstrap / Ansible](#bootstrap--ansible)
  - [BGP](#bgp)
    - [View Neighbors](#view-neighbors)
    - [View IPv4 Routes](#view-ipv4-routes)
    - [View EVPN routes](#view-evpn-routes)

## Overview
This is an ansible role to try to configure an installation of SONiC, it
is designed to work on any switch supported by SONiC.  While it is recommended
to use this against a fresh install, in theory it should be able to operate
against an already configured installation.

This role is designed to be indempotent and encapsulate the ***complete***
configuration of the switch.  It is not meant to perform a manual update of a
single setting, instead it reads in the variables set that represent the
entirety of the switch configuration and applies the diff of the configuration
from the current state.  It is expected most changes to the variables in this
role which modify the switch configuration can be completed without any sort of
outage (other than the obvious reasons, like you disabled the port you're using
to connect to the switch and configure it).

In some circumstances this may detect the configuration change is too large
and require a reboot; this is true on a fresh installation, and likely if
the switch was configured external to this role, but generally not expected to
be needed if previously configured with this role.

SONiC supported switches are listed here:
https://sonic-net.github.io/SONiC/Supported-Devices-and-Platforms.html

The latest downloads are made available here (the prior link does list some
downloads but may not be the best option):
https://sonic.software/

The documentation I used for generating the SONiC config is here:
https://github.com/sonic-net/sonic-buildimage/blob/master/src/sonic-yang-models/doc/Configuration.md
(however this document is incomplete and it is recommended to look at the
actual yang models themselves for a complete listing of options).  In theory
someone using this shouldn't need to reference these docs.

Features currently supported by this role are:
 * BGP unnumbered
 * VXLAN EVPN using BGP unnumbered
 * VLAN assignments
 * IP Address assignments
 * Static Routes

***Not*** currently supported (but will likely be in the future):
 * PortChannel (LACP) - including MLAG/MCLAG
 * Configuring auxiliary services (e.g. NTP, SNMP, Syslog)
 * Configuring Authentication
   * Local Passwords / SSH Keys
   * RADIUS

This role reads in the configuration on the device, then modifies it by
overwriting various sections, and writing it back.  We then use the
`config replace` command which merges our updates into the running config.  This
was chosen over the `config reload` command, which instead of merging changes
performs a hard reset of the entire configuration.

This role manages the BGP configuration via the FRR config directly.  Though
SONiC does have some built-in capabilities for managing BGP, it doesn't appear
it is yet capable of supporting BGP Unnumbered with VXLAN EVPN support.

## Tested On

This has been tested on [Dell S5248F](https://www.dell.com/en-us/shop/ipovw/networking-s-series-25-100gbe)
and [Dell N3248TE](https://www.dell.com/en-us/shop/ipovw/networking-n3200-series)
switches, bought off ebay (~$1100USD and ~$700USD respectively) and loaded with
the official SONiC image listed above (not Dell's Enterprise SONiC).  These
switches both use the Broadcom Trident 3 switch ASIC.

Stay away from Broadcom's Tomahawk line as it is designed for performance and
not features, so things you'd expect with SONiC (like VXLAN) won't work. Trident2
switches also lack VXLAN support. Mellanox/Nvidia Spectrum is an excellent
choice (though untested by me), but pricey even used.

## Variables used by this role

***Important***: please pay attention to whether a variable takes an array
vs a dictionary.  A dictionary entry will **NOT** have a leading `-` and its
members will be indented, while an array **will** have a leading `-` but its
members will be at the same indention level.  For example, `sonic_interfaces`
and `sonic_vlans` take dictionaries, but `sonic_routes` and the `vlans` member
of `sonic_interfaces` takes an array.  Design decisions were made for ease of
processing the variables based on how SONiC is configured. See the example
config if still confused.

* `sonic_bgp_ip`: IPv4 Address with subnet mask to use for running BGP.  This
  will set up a Loopback Interface with the address and also be configured as
  the router id and VXLAN vtep source IP address.  Example: `10.1.0.1/32`
* `sonic_asn`: Autonomous system number to use.  Should be unique per host and
  should be allocated in the private use range. Example: `4210000001`
* `sonic_interfaces`: Dictionary of the interface configurations.  The key
  is the interface index (as enumerated on the front panel of the switch).  The
  value is also a dictionary with these keys:
  * `layer3`: `true`/`false`. Whether this interface will be used as a layer3
    interface.  This enables IPv6 link-local address support and also activates
    BGP on the interface. Default is `false`.
  * `admin_status`: `up`/`down`. Whether the interface is administratively
    enabled.  Default is `down`.
  * `autoneg`: `on`/`off`. Whether the interface should enable autonegotiation.
    Defaults to `on`.
  * `adv_speeds`: Comma delimited list of speeds in Megabits per second to
    advertise if autonegotiation is enabled. Example: `10000,1000,100`.  By
    default it will use whatever the interface is capable of.
  * `speed`: Interface speed in Megabits per second. Defaults to the maximum
    port speed. Example: `25000` (25G)
  * `description`: User-provided description of the interface for convenience.
    Typically describes what is plugged into the port.  Default is "".
  * `mtu`: The MTU of the interface. Defaults to `9216` if not provided.
  * `ips`: Array of ipv4 and/or ipv6 addresses with subnet mask to assign to the
    interface.  Cannot be used with `vlans` (you should probably create a vlan
    with an ip address list instead). Example:
    `[ "1.2.3.4/24", "2620:3:4:5::6/64" ]`
  * `vlans`: Vlans to assign to an interface. The vlan must have been already
    created using the `sonic_vlans` configuration. The value is an array of
    dictionaries with these keys:
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
* `sonic_routes`: Array of dictionaries used to configure static routes.  The
  keys for the dictionary are:
  * `prefix`: IPv4 or IPv6 prefix, Example: `192.168.1.0/24`.  For a default
     gateway use `0.0.0.0/0` for ipv4 and `::/0` for ipv6. Required.
  * `nexthop`: The ip address of the next hop.  If not specified, must specify
    `ifname`.
  * `ifname`: The interface name for the next hop.  If not specified, must
    specify `nexthop`.


***NOTE***: Typically variables will be placed in the host vars, its recommended
to create a file like `host_vars/switch-fqdn.yml` that contains these settings.

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

### BGP

#### View Neighbors
Summary:
```
vtysh -c "show ip bgp summary"
```

Detail:
```
vtysh -c show bgp neighbor
```

#### View IPv4 Routes
```
vtysh -c "show ip bgp"
```

#### View EVPN routes
```
vtysh -c "show bgp l2vpn evpn route"
```

