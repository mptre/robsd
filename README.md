# robsd

This project started out as an attempt to automate the
[release(8)](release)
process on OpenBSD.
The prime motivation was to roll my own snapshots in order to test my own and
others changes to the kernel, user space and everything in between.
Hence the name robsd as in release OpenBSD.
The scope later grew and the project is by now a kitchen sink for everything
related to building, testing and maintaining OpenBSD.
It's written in ksh with a dash of C and requires nothing other than what's
included in OpenBSD.

The project is divided into the utilities as follows.

[release]: https://man.openbsd.org/release

### robsd

[robsd(8)](robsd)
builds a release according to the release process.
Some of its noteworthy features:

* The changes since the last build according to CVS is turned into a
  readable log, similar to the format seen on the *-changes mailing
  lists.
* Patches can be applied and reverted.
* Detection of build time changes.
* Detection of significant kernel and sets size changes.

[robsd]: https://www.basename.se/robsd

### robsd-ports

[robsd-ports(8)](robsd-ports)
builds ports using
[dpb(1)](dpb)
behind the scenes.

[dpb]: https://man.openbsd.org/dpb
[robsd-ports]: https://www.basename.se/robsd-ports

### robsd-regress

[robsd-regress(8)](robsd-regress) runs regression tests.

[robsd-regress]: https://www.basename.se/robsd-ports

## Installation

The installation prefix defaults to `/usr/local` and can be altered using the
`PREFIX` environment variable:

	$ make install

## License

Copyright (c) 2018-2022 Anton Lindqvist.
Distributed under the ISC license.
