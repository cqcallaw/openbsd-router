# Base System Setup
The OpenBSD [installation guide](https://www.openbsd.org/faq/faq4.html) is well-written and thorough. A few caveats:

1. Using HTTP for the file sets is recommended; I was unable to access the file sets on the USB boot media from installer's ramdisk environment.
2. For devices like the apu2d4 without a VGA (pc0) port, the installer gets stuck in a boot loop unless the default terminal is [re-configured to use the COM port](http://openbsd-archive.7691.n7.nabble.com/PC-Engines-apu2c4-install-reboot-loop-td311126.html#a311131). In short, the following commands must be typed at boot prompt.
    ```
    boot> stty com0 115200
    boot> set tty com0
    ```
    `115200` is the baud rate of the COM port.


