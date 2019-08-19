# IPv4
The [PF router guide](https://www.openbsd.org/faq/pf/example1.html) is well-written and thorough.

## Static Port NAT
Some Internet services such as Nintendo Switch Online require [static port translation](https://man.openbsd.org/pf.conf#static-port) to operate correctly. Here is an example of static port NAT from a static local IP address:

```
pass out quick on $wan proto udp from 192.168.0.220 to any nat-to ($wan) static-port
```

To match correctly, special-purpose NAT rules should be [quick](https://man.openbsd.org/pf.conf#quick) and preceed any general-purpose NAT rules. This particular rule also uses parenthesis for the nat-to destination so the translation is updated whenever the dynamically-assigned WAN IP address changes, as described in https://man.openbsd.org/pf.conf#from

# IPv6
If your ISP already supports IPv6, the [lipidity.com unofficial router guide sequel](https://lipidity.com/openbsd/router/) is well-written and thorough.

## Notes on Prefix Delegation
ISPs generally assign an IPv6 *prefix* to their customers instead of a single address. NAT is therefore not required, though having a publicly routable IP has security implications which make the use of [privacy extensions](https://tools.ietf.org/html/rfc4941) advisable.

`/64` is the standard end-user prefix length for IPv6 prefix delegations, but some ISPs provide shorter prefixes such `/48` or `/56`which allows the local network administrator to [subnet](https://www.tutorialspoint.com/ipv6/ipv6_subnetting.htm) the delegated address space into multiple local networks. The final prefix assigned to individual hosts on the network should always be `/64`, so we can form the subnet ID from the bits that must be added to the ISP-delegated prefix to obtain a prefix length of 64. These additional bits also called a Site-Level Aggregation ID or SLA ID in various IPv6 documentation.

For a `/56` prefix, we must add **8** bits to get 64, which means there are 2^8 (256) subnet IDs available. For a `/48` prefix, we must add **16** bits get a 64 bit prefix, which means there are 2^16 (65,536) subnet IDs available.
