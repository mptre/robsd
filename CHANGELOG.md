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
