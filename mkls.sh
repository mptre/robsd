mkls "$@" \
KNFMT \
	*.[ch] \
	-- \
SCRIPTS \
	!(mkls).sh \
	-- \
DISTFILES \
	*.c *.h *.md !(mkls).sh \
	robsd?(-clean|-kill|-ports|-regress|-rescue) \
	*.5 robsd?(-clean|-kill|-ports|-regress|-rescue|-stat).[0-9] \
	LICENSE Makefile Makefile.inc \
	tests/*.sh \
	tests/Makefile

cd tests
mkls "$@" \
TESTS \
	!(t|util).sh
