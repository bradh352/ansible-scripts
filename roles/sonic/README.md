# SONiC Ansible Configuration

This is an ansible role to try to configure a fresh installation of SONiC, it
is designed to work on any switch supported by SONiC.  SONiC supported
switches are listed here:
https://sonic-net.github.io/SONiC/Supported-Devices-and-Platforms.html

The latest downloads are made available here (the prior link does list some
downloads but may not be the best option):
https://sonic.software/

The documentation for config generation is here:
https://github.com/sonic-net/sonic-buildimage/blob/master/src/sonic-yang-models/doc/Configuration.md

Features currently supported by this role are:
 * BGP unnumbered
 * VXLAN EVPN using BGP unnumbered
 * VLAN assignments
 * IP Address assignments

We read in the configuration on the device, then modify it by overwriting
various sections, and writing it back.  We then use the `config replace`
command which merges our updates into the running config.  This is better than
`config reload` which brings the entire switch down.

We also manage the BGP configuration via the FRR config directly.  Though
SONiC does have some built-in capabilities, it doesn't appear we can get it
to write a BGP Unnumbered configuration with VXLAN EVPN support at this time.

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
  * `autoneg`: `on`/`off`. Whether the interface should enable autonegotiation.
    Defaults to `on`.
  * `adv_speeds`: Comma delimited list of speeds in Megabits per second to
    advertise if autonegotiation is enabled. Example: `10000,1000,100`.  By
    default it will use whatever the interface is capable of.
  * `speed`: Interface speed in Megabits per second. Defaults to the maximum
    port speed. Example: `25000` (25G)
  * `description`: User-provided description of the interface for convenience.
    Typically describes what is plugged into the port.  Default is "".
  * `ips`: Array of ipv4 and/or ipv6 addresses with subnet mask to assign to the
    interface.  Cannot be used with `vlans` (you should probably create a vlan
    with an ip address list instead). Example:
    `[ "1.2.3.4/24", "2620:3:4:5::6/64" ]`
  * `vlans`: Vlans to assign to an interface, the value is an array of
     dictionaries with these keys:
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

Can be run with something like:
```
ansible-playbook -vvv playbook.yml --limit sw1.testenv.bradhouse.dev -e ansible_password=YourPaSsWoRd
```

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

