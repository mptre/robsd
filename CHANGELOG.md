# 14.0.0 - 2022-11-08

## Changes

- Stop requiring a robsd-regress user and instead default to the build user.
  The user can be specified per regression test.
  (a774542, 8da8234)
  (Anton Lindqvist)

## News

- Delete unused dependencies in robsd-regress pkg-del step.
  (9efadff)
  (Anton Lindqvist)
# 13.4.0 - 2022-11-07

## News

- Allow make target per regress test to be specified.
  (a01155a)
  (Anton Lindqvist)

# 13.3.3 - 2022-11-06

## Bug fixes

- Fix off by one in buffer memory allocation.
  (f18c687)
  (Anton Lindqvist)

# 13.3.2 - 2022-10-21

## Bug fixes

- Ignore pkg_delete failures in robsd-regress pkg-del step.
  (a032b0f)
  (Anton Lindqvist)

# 13.3.1 - 2022-10-21

## Bug fixes

- Perform one pkg_add invocation during the robsd-regress pkg-add step.
  (1a2ddfb)
  (Anton Lindqvist)

# 13.3.0 - 2022-10-20

## News

- Add support for installing additional packages to robsd-regress.
  (121c7a1, be92ae3)
  (Anton Lindqvist)

# 13.2.0 - 2022-09-16

## News

- Add support for building one or more non-configured robsd-ports.
  (4fe4da0)
  (Anton Lindqvist)

- Add robsd-ports-rescue.
  (c6b0078)
  (Anton Lindqvist)

## Bug fixes

- Add missing util.sh includes.
  (e3a37c5)
  (Anton Lindqvist)

- Tags might be absent during robsd hash step.
  (7fb0fb4)
  (Anton Lindqvist)

- Prune on cvs checkout.
  (8b0d95e)
  (Anton Lindqvist)

- Fix dpb error detection in robsd-ports.
  (a507d4d)
  (Anton Lindqvist)

# 13.1.0 - 2022-07-18

## News

- Stop including all util files.
  (aed7a5d)
  (Anton Lindqvist)

# 13.0.0 - 2022-07-12

## Changes

- Set MAKEFLAGS for robsd-cross.
  (92fa59a)
  (Anton Lindqvist)

- Remove kernel step from robsd-cross.
  (5d03c2c)
  (Anton Lindqvist)

## Bug fixes

- Fix cvs checkout, caused by a typo in shell command.
  (d5db529)
  (Anton Lindqvist)
# 12.4.0 - 2022-06-27

## News

- Add arch and machine config interpolation variables.
  (52b86fb)
  (Anton Lindqvist)

# 12.3.0 - 2022-06-27

## News

- Add cvs step to robsd-regress.
  (129af92)
  (Anton Lindqvist)

- Extract make errors visible in robsd-regress report.
  Used as a fallback when a test suite fails before running any tests.
  (b2e800d)
  (Anton Lindqvist)

## Bug fixes

- Fix cvs checkout using a different local directory.
  (2d1fc20)
  (Anton Lindqvist)

# 12.2.0 - 2022-06-10

## News

- Add obj step to robsd-regress used to create object directories for all
  configured regression tests.
  (ff66ea7)
  (Anton Lindqvist)

- Add support for creating additional obj directories to robsd-regress.
  (e7f888e)
  (Anton Lindqvist)

# 12.1.0 - 2022-06-08

## News

- Perform initial checkout in cvs step if the directory is empty.
  (44296d1)
  (Anton Lindqvist)

## Bug fixes

- Don't leave dangling files in /tmp around.
  (9642686)
  (Anton Lindqvist)

# 12.0.2 - 2022-06-07

## Bug fixes

- Use the canonical arch in robsd-ports.
  (6f4ca64)
  (Anton Lindqvist)

# 12.0.1 - 2022-06-07

## Bug fixes

- Fix missing target regression in robsd-crossenv.
  (a7f980b)
  (Anton Lindqvist)

# 12.0.0 - 2022-06-04

## Changes

- Rework robsd-regress configration.
  (87f8ecc)
  (Anton Lindqvist)

## News

- Add clean step to robsd-ports.
  (a10607b)
  (Anton Lindqvist)

- Add inet interpolation variable to robsd-regress.
  (eed5866)
  (Anton Lindqvist)

# v11.6.1 - 2022-05-26

## Bug fixes

- Fix detection of failed and skipped regress tests while running as root.
  (c9cc023)
  (Anton Lindqvist)

# v11.6.0 - 2022-05-18

## News

- Teach regress to dump installed packages as part of the env step.
  Helpful while debugging failures that depend on packages.
  (e8d8145)
  (Anton Lindqvist)

## Bug fixes

# v11.5.2 - 2022-05-17

## Bug fixes

- Never let regress fail early.
  (74652ef)
  (Anton Lindqvist)

# v11.5.1 - 2022-05-13

## Bug fixes

- Honor the regress skip configuration when including failing test cases in
  report.
  (9e2aec4)
  (Anton Lindqvist)

# v11.5.0 - 2022-05-12

## News

- Improve extraction of failed and skipped regress test cases.
  (117d8fc)
  (Anton Lindqvist)

- Add configure script, paving the way for compilation on Linux.
  (e4794ca)
  (Anton Lindqvist)

# v11.4.0 - 2022-05-10

## News

- Report disabled regress test cases.
  (3624d7e)
  (Anton Lindqvist)

# v11.3.1 - 2022-05-10

## Bug fixes

- Normalize step specific headers included in report.
  (1405c17)
  (Anton Lindqvist)

# v11.3.0 - 2022-05-09

## News

- Include the name of the failed and skipped regress tests in report.
  (b1a9bfc)
  (Anton Lindqvist)

# v11.2.0 - 2022-04-28

## News

- Add robsd-crossenv utility.
  (00e2def)
  (Anton Lindqvist)

- Zero pad log file names even further.
  (81f2af4)
  (Anton Lindqvist)

# v11.1.0 - 2022-02-28

## News

- Use bsd.regress.mk markers to split test cases.
  (51510fc)
  (Anton Lindqvist)

# v11.0.0 - 2022-02-22

## Changes

- Compile the GENERIC.MP kernel by default, as opposed of choosing the
  kernel configuration based on the number of CPUs online.
  The kernel configuration can be specified using the new kernel configuration
  variable.
  (25aa85e)
  (Anton Lindqvist)

## News

- Add robsd-cross, used to cross compile the kernel.
  (25aa85e)
  (Anton Lindqvist)

- Allow interpolation of configuration variables, making it possible to refer to
  other configuration variables.
  (25aa85e)
  (Anton Lindqvist)

## Bug fixes

- Some architectures does not support performance tuning.
  (1d4e4fe)
  (Anton Lindqvist)

# v10.0.0 - 2022-02-10

## Changes

- Rework hook configuration.
  Introducing the robsd-hook utlitity in charge of executing any configured hook.
  In addition, the hook configuration is also interpolated instead of passing a
  fixed set of arguments.
  (14a5156)
  (Anton Lindqvist)

# 9.0.0 - 2022-02-07

## Changes

- Turn rdonly regress configuration variable into a boolean.
  (5262967)
  (Anton Lindqvist)

- Make reboot step optional, it can be enabled using the new reboot
  configuration variable.
  (b469abd)
  (Anton Lindqvist)

## News

- Detect ports dependency failures.
  (a6138be)
  (Anton Lindqvist)

- Make cvs step optional based on presence of configuration.
  (fc9b4eb)
  (Anton Lindqvist)

## Bug fixes

- Close common file descriptors in robsd-stat, allowing boot process to continue
  while resuming from rc.firsttime.
  (4e2850b)
  (Anton Lindqvist)

# 8.0.1 - 2022-02-04

## Bug fixes

- Fix SUDO regression in robsd-regress causing the environment variable to not
  be exported.
  (d292b4e)
  (Anton Lindqvist)

# 8.0.0 - 2022-02-03

## Changes

- Rework configuration.
  Introducing the robsd-config utility in charge of the configuration.
  This gives a better view of the configuration required by each step as the
  configuration no longer is expressed using global variables.
  (d934099)
  (Anton Lindqvist)

# 7.3.0 - 2022-01-30

## News

- Clean and try to rebuild the kernel once on failure.
  (a4e6abe)
  (Anton Lindqvist)

- Detect early dpb ports build failures.
  (fd0c15b)
  (Anton Lindqvist)

- Handle diffs with files in new directories.
  (ba3f0c8, 6d8d2da)
  (Anton Lindqvist)

# 7.2.0 - 2022-01-08

## Bug fixes

- Fix naming conflict caused by regression tests overlapping with another step
  name.
  (e85eb34)
  (Anton Lindqvist)

## News

- Add mount BSDSRCDIR read-only support to robsd-regress.
  Used to detect object directory ignorance.
  (76b4619)
  (Anton Lindqvist)

# 7.1.0 - 2022-01-07

## News

- Add patch support to robsd-regress.
  (fb07d85)
  (Anton Lindqvist)

# 7.0.0 - 2022-01-05

## Changes

- Invert detach option, running in the background is now the default.
  (38467b9)
  (Anton Lindqvist)

## News

- Add patch support to robsd-ports.
  (7f053fa)
  (Anton Lindqvist)

# 6.0.0 - 2021-12-18

## Changes

- Make use of dpb(1) under the hood in robsd-ports.
  (87f8532)
  (Anton Lindqvist)

# 5.3.2 - 2021-12-05

## Bug fixes

- Look for root owned processes in robsd-stat during robsd-regress.
  (ff23f2f)
  (Anton Lindqvist)

# 5.3.1 - 2021-12-03

## Bug fixes

- Make robsd-stat capable of figuring out the current working directory for
  robsd-ports and robsd-regress.
  (600fe55)
  (Anton Lindqvist)

# 5.3.0 - 2021-12-01

## Bug fixes

- Correct robsd-ports detection of outdated dependencies.
  (9260b25, 88ab60b, 8772c36)
  (Anton Lindqvist)

- Document skip option in robsd-ports manual.
  (b9089a0)
  (Anton Lindqvist)

- Ensure robsd-ports signs all packages, including debug packages.
  (2fcf179)
  (Anton Lindqvist)

## News

- Add support for flagging ports that cannot be built in parallel.
  (ed0f5d7)
  (Anton Lindqvist)

- Add robsd-stat, used to collect system statistics.
  (af95f23)
  (Anton Lindqvist)

# 5.2.0 - 2021-10-26

## News

- Improve robsd-regress log excerpt in report when there's no failing nor
  skipped targets.
  (1b1fbe7)
  (Anton Lindqvist)

- Only keep the first env.log in the attic.
  (89816ea)
  (Anton Lindqvist)

# 5.1.0 - 2021-10-25

## Bug fixes

- Always use SUBDIR with make in robsd-ports.
  (0d7d6be)
  (Anton Lindqvist)

## News

- Make cvs section in report less noisy by removing sh(1) traces.
  (4990015)
  (Anton Lindqvist)

- Pass the invoking user to HOOK.
  (086ee5b)
  (Anton Lindqvist)

- Include the CVS date of the last updated revision in robsd BUILDINFO.
  Intended to be used in conjuction with robsd-regress to checkout the same
  source tree.
  (c3b67cd)
  (Anton Lindqvist)

- Add tags support to all utilities.
  (b60adc6)
  (Anton Lindqvist)

# 5.0.2 - 2021-10-10

## Bug fixes

- Install robsd-kill manual.
  (7e6a13f)
  (Anton Lindqvist)

- Make robsd-kill kill the correct corresponding robsd utility.
  (de9e860)
  (Anton Lindqvist)

# 5.0.1 - 2021-10-08

## Bug fixes

- Fix robsd-exec path in robsd-kill.
  (6586a6f)
  (Anton Lindqvist)

# 5.0.0 - 2021-10-08

## Changes

- Remove no parallel robsd-regress flag support, defaults to running with make
  parallelism disabled.
  (87d97ab)
  (Anton Lindqvist)

## News

- Keep temporary directory around, useful while debugging.
  (8ef532e)
  (Anton Lindqvist)

- Build all dependenices in robsd-ports.
  (cc3dcd6)
  (Anton Lindqvist)

- Add robsd-kill utility.
  Especially useful when killing robsd-ports or robsd-regress since they
  continue despite encountering a failing step.
  (0e9bf63)
  (Anton Lindqvist)

## Bug fixes

- Do not ignore non-zero exits during default steps in robsd-ports and
  robsd-regress.
  (a969593)
  (Anton Lindqvist)

# 4.1.0 - 2021-10-03

## News

- Add build identifier to BUILDINFO release file.
  Intended to be used to correlate robsd and robsd-ports invocations.
  (798ee8d)
  (Anton Lindqvist)

- Change robsd-ports and robsd-regress failure report subject, count the number
  of failures as opposed of displaying the last failing step.
  (41e5923)
  (Anton Lindqvist)

- Add comment option back to all utilities.
  (0f8a28d)
  (Anton Lindqvist)

# 4.0.0 - 2021-10-01

## Changes

- Remove robsd-steps utility, all steps are documented in each respective
  manual instead.
  (0495780)
  (Anton Lindqvist)

## News

- Add robsd-ports, used to build ports.
  Currently a work in progress.
  (de82b30)
  (Anton Lindqvist)

- Add missing pledge to robsd-exec.
  (260d3dd)
  (Anton Lindqvist)

## Bug fixes

- Handle missing new lines while extracing regress logs.
  (92aad52)
  (Anton Lindqvist)

- Unblock SIGHUP in robsd-exec.
  (0f22a78)
  (Anton Lindqvist)

# 3.0.0 - 2021-09-21

## Changes

* Rename configuration variable BUILDDIR to ROBSDDIR.
  (5fb74a1)
  (Anton Lindqvist)

# 2.1.0 - 2021-09-17

## News

- Add support for run as root robsd-regress regression test flag.
  (ee42152)
  (Anton Lindqvist)

# 2.0.4 - 2021-09-16

## Bug fixes

- Unset DESTDIR in robsd-regress, preventing some tests from picking up compiler
  flags in bsd.sys.mk.
  (cc6f743)
  (Anton Lindqvist)

# 2.0.3 - 2021-09-15

## Bug fixes

- Clarify that diff path names can be relative to any directory.
  (f253311)
  (Anton Lindqvist)

# 2.0.2 - 2021-09-14

## Bug fixes

- Unblock common signals in robsd-exec.
  (13b1ca8)
  (Anton Lindqvist)

- If a regress log does not contain any FAILED nor SKIPPED markers, include the
  tail of the log instead of showing nothing in the report. Can happen if
  something for instance fails to build.
  (e225eaa)
  (Anton Lindqvist)

# 2.0.0 - 2021-09-10

## Changes

- Consolidate regress test configuration.
  Instead using three different configuration variables for declaring regress
  tests, add the ability to annotate each test as part of the TESTS configuration
  variable.
  This is a breaking change since NOTPARALLEL and SKIPIGNORE are no longer
  honored.
  (9ceac51)
  (Anton Lindqvist)

# 1.6.0 - 2021-09-09

## News

- Optionally omit skipped regress targets from report using the SKIPIGNORE
  configuration variable.
  (ebcb35d)
  (Anton Lindqvist)

# 1.5.0 - 2021-07-17

## News

- Optionally disable make parallelism for certain regress tests.
  The configuration now honors a list of such tests named NOTPARALLEL.
  (4749a59)
  (Anton Lindqvist)

## Bug fixes

- Adjust environment variables preserved by su(1).
  Required by some regress tests
  (0c4d1fa)
  (Anton Lindqvist)

# 1.4.3 - 2021-07-11

## Bug fixes

- Include all failing regress tests in the report.
  (f96be5c)
  (Anton Lindqvist)

# 1.4.2 - 2021-07-08

## Bug fixes

- Detect regress test failures by examining the log as tests can exit zero
  despite failure.
  (296f9ea)
  (Anton Lindqvist)

# 1.4.1 - 2021-07-07

## Bug fixes

- Install signal handlers after fork in robsd-exec preveting SIGPIPE
  from being ignored by the child.
  (a82b872)
  (Anton Lindqvist)

# 1.4.0 - 2021-07-07

## News

- Include skipped regress tests in report.
  (c1cb6b9)
  (Anton Lindqvist)

# 1.3.0 - 2021-07-01

## News

- Describe diff file name convention in manual.
  (e51b7a7)
  (Anton Lindqvist)

- Use host name as opposed of machine architecture in mail subject.
  (8d7e35e)
  (Anton Lindqvist)

- Let robsd-rescue release the build lock, allowing a new release to be
  built.
  (382d58b)
  (Anton Lindqvist)

- Adjust the build date in BUILDINFO to the start of the release build.
  To be used by robsd-regress at some point.
  (79a27fe)
  (Anton Lindqvist)

## Bug fixes

- Execute aborted steps again upon resume.
  (1189f76, ed4eec0, 9120b78)
  (Anton Lindqvist)

# 1.2.0 - 2021-05-17

## News

- Suppress stdout output during resume.
  Gets rid of the informative messages delivered as a mail from rc.firsttime.
  (f892545)
  (Anton Lindqvist)

- Make it possible to optionally sign the release artifacts and generate
  index.txt without distributing the same artifacts to another host during the
  distrib step.
  (30e3309)
  (Anton Lindqvist)

- Add robsd-regress, used to run regress test suite.
  (bba1ef1)
  (Anton Lindqvist)

- Add a comment with the original path to each diff.
  (9b7d376)
  (Anton Lindqvist)

# v1.1.0 - 2020-09-29

## News

- Make distrib configuration optional.
  (c0d651a)
  (Anton Lindqvist)

# v1.0.1 - 2020-09-25

## Bug fixes

- Correct DESTDIR owner and permissions.
  (618abf3)
  (Anton Lindqvist)

# v1.0.0 - 2020-09-23

## News

- First somewhat stable release.
  (Anton Lindqvist)
