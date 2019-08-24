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