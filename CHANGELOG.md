# 1.3.0 2021-07-01

## Bug fixes

- Execute aborted steps again upon resume.
  (1189f76, ed4eec0, 9120b78)
  (Anton Lindqvist)

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

# 1.2.0 2021-05-17

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
