# robsd

This project started out as an attempt to automate the
[release(8)](release)
process on OpenBSD in order to roll my own snapshots.
The prime motivation was to test my own and others changes to the kernel, user
space and everything in between.
Hence the name robsd as in release OpenBSD.
The scope later grew and the project is by now a kitchen sink for everything
related to building, testing and maintaining OpenBSD.

The project is divided into the utilities as follows.

[release]: https://man.openbsd.org/release

### robsd

XXX
XXX try out diffs (src, xenocara)
XXX report step time increase, size increase, cvs log

### robsd-ports

XXX

### robsd-regress

XXX

## Installation

The installation prefix defaults to `/usr/local` and can be altered using the
`PREFIX` environment variable:

	$ make install

## License

Copyright (c) 2018-2021 Anton Lindqvist.
Distributed under the ISC license.
