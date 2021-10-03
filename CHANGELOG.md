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
