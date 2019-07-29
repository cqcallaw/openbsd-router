A guide to using OpenBSD for a dual stack (IPv4 and IPv6) SOHO router. Tested on a PC Engines [apu2d4](https://pcengines.ch/apu2d4.htm) with [OpenBSD 6.5](https://www.openbsd.org/65.html)

# Base System
The OpenBSD [installation guide](https://www.openbsd.org/faq/faq4.html) is well-written and thorough. A few caveats:

1. Using HTTP for the file sets is recommended; I was unable to access the file sets on the USB boot media from installer's ramdisk environment.
2. For devices like the apu2d4 without a VGA (pc0) port, the installer gets stuck in a boot loop unless the default terminal is [re-configured to use the COM port](http://openbsd-archive.7691.n7.nabble.com/PC-Engines-apu2c4-install-reboot-loop-td311126.html#a311131). To summarize, the following commands must be typed at boot prompt.
    ```
    stty com0 115200
    set tty com0
    ```
    `115200` is the baud rate of the COM port.

# IPv4 Router Setup
The [PF router guide](https://www.openbsd.org/faq/pf/example1.html) is well-written and thorough.

# IPv6 Router Setup
If your ISP already supports IPv6, the [lipidity.com unofficial router guide sequel](https://lipidity.com/openbsd/router/) is well-written and thorough.

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
The 6in4 tunnel generates [Protocol 41](https://simple.wikipedia.org/wiki/Protocol_41) traffic, which isn't passed by basic pf rulesets. Protocol 41 traffic can be passed with an update to `/etc/pf.conf` of the following form:
```
tunnel = "<HE IPv4 endpoint>"
wan = "<WAN interface>"
...
pass in proto 41 from $tunnel to $wan keep state
pass out proto 41 from $wan to $tunnel keep state
```

Reload pf rules with `pfctl -f /etc/pf.conf` for the change to take effect.

## Dynamic Client Endpoint Updates
If your ISP assigns dynamic IPv4 addresses (as many ISPs do), Hurricane Electric's servers must be notified when the tunnel's IPv4 client endpoint changes. This is best accomplished with a script that runs as a cronjob.

```
#!/bin/sh
# HE tunnel update, based on https://github.com/chapmajs/Examples/blob/master/openbsd/update_he.sh

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later 
# version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more 
# details.

# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.

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

This script will run as a cronjob, so save it in a convenient location (I use `/etc/tunnel_update.sh`), then edit the root crontab:

```
crontab -e -u root
```

You should see the crontab editor load (usually this is [vim](http://vimsheet.com/)). Add the following lines to run the update script every 15 minutes:

```
# update HE.net tunnel endpoint
15      *       *       *       *       /bin/sh /path/to/tunnel_update_script.sh
```

Save and quit to apply the changes.

### Firewall Rules for Dynamic Endpoint Update

Hurricane Electric's servers will ping the new IP address to verify its availability before updating the tunnel endpoint, so it's also important to ensure pf permits ping requests from HE's server:

```
pass in on egress proto icmp from 66.220.2.74
```
