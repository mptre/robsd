mkls -s "$@" -- \
COMPATS		compat-*.c -- \
KNFMT		!(compat-*).c !(config).h -- \
CLANGTIDY	!(config|compat-*).h !(compat-*).c -- \
CPPCHECK	!(compat-*).c -- \
IWYU		!(compat-*).c !(config).h -- \
SCRIPTS		!(mkls).sh -- \
MANLINT		*.[0-9] -- \
SHLINT		'${SCRIPTS}' canvas configure robsd robsd-!(*.*) tests/!(t).sh

cd tests
mkls -s "$@" -- \
TESTS	!(t|util).sh
