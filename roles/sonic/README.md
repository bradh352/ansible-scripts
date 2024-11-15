# SONiC Ansible Configuration

This is an ansible role to try to configure a fresh installation of SONiC, it
is designed to work on any switch supported by SONiC.  SONiC supported
switches are listed here:
https://sonic-net.github.io/SONiC/Supported-Devices-and-Platforms.html

The latest downloads are made available here (the prior link does list some
downloads but may not be the best option):
https://sonic.software/

Features currently supported by this role are:
 * BGP unnumbered
 * VXLAN EVPN using BGP unnumbered
 * VLAN assignments
 * IP Address assignments

## Variables used by this role

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
  * `description`: User-provided description of the interface for convenience.
    Typically describes what is plugged into the port.  Default is "".
  * `ips`: Array of ipv4 and/or ipv6 addresses with subnet mask to assign to the
    interface.  Cannot be used with `vlans` (you should probably create a vlan
    with an ip address list instead). Example:
    `[ "1.2.3.4/24", "2620:3:4:5::6/64" ]`
  * `vlans`: Vlans to assign to an interface, the value is a dictionary with
    these fields:
    * `vlan`: Vlan id to use (1-4096), required.
    * `mode`: `tagged`/`untagged`. Only a single vlan may be marked as untagged
      for a single interface.
* `sonic_vlans`: Dictionary of the VLAN/VXLAN configuration. The key is the
  VLAN id.  The value is also a dictionary with these keys:
  * `vxlan`: If mapping a VXLAN to a VLAN, this is the VXLAN id. Valid range
    is 1-16777214.  This is necessary if you want to be able to forward a
    vxlan to a connected device that is not participating in the VXLAN-EVPN.
  * `ips`: Array of ipv4 and/or ipv6 addresses with subnet mask to assign to the
    vlan virtual interface. Example: `[ "1.2.3.4/24", "2620:3:4:5::6/64" ]`
  * `layer3`: `true`/`false`. Whether this interface will be used as a layer3
    interface.  This enables IPv6 link-local address support. Default is
    `false`.

***NOTE***: Typically variables will be placed in the host vars, its recommended
to create a file like `host_vars/switch-fqdn.yml` that contains these settings.

## Useful SONiC commands

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
