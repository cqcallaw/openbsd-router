A guide to using OpenBSD for a dual stack (IPv4 and IPv6) SOHO router. Tested on a PC Engines [apu2d4](https://pcengines.ch/apu2d4.htm) with [OpenBSD 6.5](https://www.openbsd.org/65.html)

# Base System
The OpenBSD [installation guide](https://www.openbsd.org/faq/faq4.html) is well-written and thorough. A few caveats:

1. Using HTTP for the file sets is recommended; I was unable to access the file sets on the USB boot media from installer's ramdisk environment.
2. For devices like the apu2d4 without a VGA (pc0) port, the installer gets stuck in a boot loop unless the default terminal is [re-configured to use the COM port](http://openbsd-archive.7691.n7.nabble.com/PC-Engines-apu2c4-install-reboot-loop-td311126.html#a311131). To summarize, the following commands must be typed at boot prompt.
```
stty com0 115200
set tty com0
```
"115200" is the baud rate of the COM port.
# IPv4 Router Setup
The [PF router guide](https://www.openbsd.org/faq/pf/example1.html) is well-written and thorough.

# IPv6 Router Setup
The [lipidity.com unofficial router guide sequel](https://lipidity.com/openbsd/router/) is well-written and thorough.

# Hurricane Electric Tunnel Setup
