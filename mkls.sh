set -e

mkls "$@" \
SCRIPTS \
	!(mkls).sh \
	-- \
DISTFILES \
	*.c *.md !(mkls).sh \
	robsd?(-clean|-kill|-ports|-regress|-rescue) \
	robsd?(.conf|-clean|-kill|-ports|-regress|-rescue|-stat).[0-9] \
	LICENSE Makefile Makefile.inc \
	tests/*.sh \
	tests/Makefile

cd tests
mkls "$@" \
TESTS \
	!(t|util).sh
