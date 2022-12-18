# robsd

This project started out as an attempt to automate the
[release(8)](https://man.openbsd.org/release)
process on OpenBSD.
The prime motivation was to roll my own snapshots in order to test my and others
changes to the kernel, user space and everything in between.
Hence the name robsd as in release OpenBSD.
The scope later grew and the project is by now a kitchen sink for everything
related to building, testing and maintaining OpenBSD.
It's written in ksh with a dash of C and requires nothing other than what's
included in base.

The project is divided into the utilities as follows.
All of them are configured using a grammar that should be familiar for anyone
with prior OpenBSD experience.

### robsd

[robsd(8)](https://www.basename.se/robsd/robsd.8.html)
builds a release according to the release process.
Some of its noteworthy features:

* The changes since the last build according to CVS is turned into a
  readable log, similar to the format seen on the *-changes mailing
  lists.
* Patches can be applied and reverted.
* Detection of build time changes.
* Detection of significant kernel and sets size changes.

### robsd-cross

[robsd-cross(8)](https://www.basename.se/robsd/robsd-cross.8.html)
builds a cross compiler tool chain targeting another architecture,
using `${BSDSRCDIR}/Makefile.cross` behind the scenes.

### robsd-ports

[robsd-ports(8)](https://www.basename.se/robsd/robsd-ports.8.html)
builds ports using
[dpb(1)](https://man.openbsd.org/dpb)
behind the scenes.

### robsd-regress

[robsd-regress(8)](https://www.basename.se/robsd/robsd-regress.8.html)
runs regression tests.
A HTML summary can be rendered using
[robsd-regress-html(8)](https://www.basename.se/robsd/robsd-regress-html.8.html),
which also powers
[regress.basename.se](https://regress.basename.se/).

## Installation

The installation prefix defaults to `/usr/local` and can be altered using the
`PREFIX` environment variable:

	$ make install

## License

Copyright (c) 2018-2022 Anton Lindqvist.
Distributed under the ISC license.
