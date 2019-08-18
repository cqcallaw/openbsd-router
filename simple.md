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
