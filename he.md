# Hurricane Electric Tunnel Setup
For folks lacking native IPv6 support or a static IPv6 prefix, Hurricane Electric's [Tunnel Broker](https://www.tunnelbroker.net/) provides a clean, stable [6in4](https://en.wikipedia.org/wiki/6in4) service.

The tunnelbroker.net web interface provides a sample tunnel configuration, typically saved in `/etc/hostname.gif0`. Below is an example configuration, borrowed from [Glitchworks](https://github.com/chapmajs/Examples/blob/master/openbsd/hostname.gif0). In this example, `209.51.161.14` is the Hurricane Electric IPv4 tunnel endpoint, `2001:db8:1::1` is the Hurricane Electric IPv6 tunnel endpoint, and `2001:db8:1::2` is the client tunnel endpoint. Addresses from the `2001:db8:1::` prefix **should not** be assigned to local hosts. A separate, routed prefix for assignment to local hosts is provided in the tunnel settings page.

```
description "Hurricane Electric IPv6 tunnel"
!ifconfig gif0 tunnel $(ifconfig egress | awk '$1 ~ /^inet$/{print $2}') 209.51.161.14
!ifconfig gif0 inet6 alias 2001:db8:1::2 2001:db8:1::1 prefixlen 128
!route -n add -inet6 default 2001:db8:1::1
```

## Firewall Rules for 6in4 Tunneling
The 6in4 tunnel generates [Protocol 41](https://simple.wikipedia.org/wiki/Protocol_41) traffic, which isn't passed by basic pf rulesets. Protocol 41 traffic can be passed by updating `/etc/pf.conf` with rules of the following form:
```
tunnel = "<HE IPv4 endpoint>"
wan = "<WAN interface>"
...
pass in proto 41 from $tunnel to $wan keep state
pass out proto 41 from $wan to $tunnel keep state
```

Reload pf rules with `pfctl -f /etc/pf.conf` for the change to take effect.

## Dynamic IPv4 Client Endpoint Updates
If your ISP assigns dynamic IPv4 addresses, Hurricane Electric must be notified whenever the tunnel's IPv4 client endpoint changes. This is best accomplished with a simple `curl` script triggered by [ifstated](https://man.openbsd.org/ifstated.8).

To enabled dynamic client endpoint updates:

1. Install curl and ifstated prerequisites:
   ```
   # pkg_add curl
   # rcctl enable ifstated
   ```
2. Save [tunnel_update.sh](tunnel_update.sh) to any convenient location on the router; I use `/etc/tunnel_update.sh`
3. Save [ifstated.conf](ifstated.conf) to `/etc/ifstated.conf` on the router
4. Update the interface names in `ifstated.conf` as necessary

### Firewall Rules for Dynamic Endpoint Update
The Tunnel Broker service will ping the new IP address to verify its availability before updating the tunnel endpoint, so it's also important to ensure pf allows these ping requests:

```
pass in on egress proto icmp from 66.220.2.74
```

## Multihoming
If Hurricane Electric's tunneling service is deployed together with some other IPv6 link (i.e. [IPv6 multihoming](https://en.wikipedia.org/wiki/Multihoming#IPv6_multihoming)), requests that originate from addresses in the HE prefix must be routed through the HE tunnel, or response packets may get dropped by the service. This type of packet loss can be avoided with source-based routing, which routes traffic based on source address instead of destination address. To enabled source-based routing for the HE tunnel:

1. **Remove** any default route configuration from the tunnel interface file `hostname.gif0`
2. Add the following rules to `/etc/pf.conf`:
```
...
lan = "em0"
he_prefix = "<he_local_prefix>::/<he_local_prefix_length>"
he_gw_addr = "<HE gateway IP>"
...

# route HE traffic to HE interface
## make sure well-known multicast traffic doesn't get re-routed (core features like NDP would break)
pass in quick on $lan to ff00::/12
## make sure traffic addressed to the local gateway doesn't get re-routed
pass in quick on $lan from $he_prefix to $he_gw_addr
pass in quick on $lan from $he_prefix route-to $he_if
...
```
