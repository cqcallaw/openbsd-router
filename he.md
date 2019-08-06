# Hurricane Electric Tunnel Setup
For folks lacking native IPv6 support or a static IPv6 prefix, Hurricane Electric's [tunnel broker](https://www.tunnelbroker.net/) provides a clean, stable [6in4](https://en.wikipedia.org/wiki/6in4) service.

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

## Dynamic Client Endpoint Updates
If your ISP assigns dynamic IPv4 addresses to their clients, Hurricane Electric must be notified when the tunnel's IPv4 client endpoint changes. This is best accomplished with a simple `curl` script triggered by [ifstated](https://man.openbsd.org/ifstated.8).

This technique requires curl and ifstated, so we can start by enabling these prerequisites:

```
# pkg_add curl
# rcctl enable ifstated
```

The following tunnel broker update script wraps `curl` with some helpful logging information:

```
#!/bin/sh
# HE tunnel update, based on https://github.com/chapmajs/Examples/blob/master/openbsd/update_he.sh

USERNAME=<user name>
PASSWORD=<tunnel password>
TUNNEL_ID=<tunnel password>
TUNNEL_IF=gif0
HE_ENDPOINT=<Hurricane Electric IPv4 tunnel end point>

function error_exit
{
	>&2 echo "Update failed, result was $1"
	exit 1
}

result=$(/usr/local/bin/curl -sS -u $USERNAME:$PASSWORD https://ipv4.tunnelbroker.net/nic/update?hostname=$TUNNEL_ID)

case $( echo "$result" | awk '{ print $1 }' ) in
	nochg)
		echo "Update succeeded, no change in IP"
		;;
	good)
		new_ip=$( echo "$result" | awk '{ print $2 }' )
		
		if [ "$new_ip" = "127.0.0.1" ]; then
			error_exit $result
		else
			echo "Update succeeded, updating $TUNNEL_IF to $new_ip"
			/sbin/ifconfig $TUNNEL_IF tunnel $new_ip $HE_ENDPOINT
		fi;
		;;
	*)
		error_exit $result
esac
```

This script can be saved in any convenient location; I use `/etc/tunnel_update.sh`.

`ifstated` is controlled by the `/etc/ifstated.conf` configuration file; the following config will trigger a tunnel endpoint update based on the state of network interface `em1`. The observed interface(s) can be adjusted as necessary:

```
# Adapted from https://github.com/vedetta-com/vedetta/blob/master/src/etc/ifstated.conf

# Global Configuration

init-state auto

# Macros

egress_up  = "em1.link.up"

# ping a well-known IPv4 address to check for connectivity
# any well-known IPv4 address can be used here
inet  = '( "ping -q -c 1 -w 4 72.52.104.74 > /dev/null" every 60 )'

# State Definitions

state auto {
	if (! $egress_up) {
		run "logger -t ifstated '(auto) egress down'"
		set-state ifdown
	}
	if ($egress_up) {
		run "logger -t ifstated '(auto) egress up'"
		set-state ifup
	}
}

state ifdown {
	init {
		run "sh /etc/netstart em1 && \
		     logger -t ifstated '(ifdown) egress reset'"
	}
	if ($egress_up) {
		run "logger -t ifstated '(ifdown) egress up'"
		set-state ifup
	}
}

state ifup {
        init {
                run "logger -t ifstated '(ifup) entered ifup state'"
        }
	if ($inet) {
		run "logger -t ifstated (ifup) IPv4 connection established."
		set-state internet
	}
	if (! $inet && "sleep 10" every 10) {
		run "logger -t ifstated '(ifup) IPv4 down'"
		set-state ifdown
	}
}

state internet {
        init {
                run "logger -t ifstated '(ifup) entered internet state'"
        }
	if ($inet) {
		run "logger -t ifstated (internet) Running tunnelbroker update..."
		run "sh /etc/tunnel_update.sh | logger -t tb.net"
		run "logger -t ifstated (internet) Ran tunnelbroker update"
	}
	if (! $inet) {
		run "logger -t ifstated (internet) Lost IPv4 connection"
		set-state auto
	}
}
```

### Firewall Rules for Dynamic Endpoint Update
The Tunnelbroker service will ping the new IP address to verify its availability before updating the tunnel endpoint, so it's also important to ensure pf allows these ping requests:

```
pass in on egress proto icmp from 66.220.2.74
```

## Multihoming with Hurricane Electric
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
