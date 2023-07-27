mkls -s "$@" -- \
SRCS		!(fuzz-*|robsd-*).c $(cd libks && ls *.c) -- \
KNFMT		!(compat-*).c !(config).h -- \
CLANGTIDY	!(config|compat-*).h !(compat-*).c -- \
CPPCHECK	!(compat-*).c -- \
SCRIPTS		!(mkls).sh -- \
SHLINT		'${SCRIPTS}' configure robsd robsd-!(*.*) tests/!(t).sh

cd tests
mkls -s "$@" -- \
TESTS	!(t|util).sh
