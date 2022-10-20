mkls "$@" \
KNFMT \
	!(compat-*).c !(config).h \
	-- \
CLANGTIDY \
	!(config|compat-*).h !(compat-*).c \
	-- \
SCRIPTS \
	!(mkls).sh \
	-- \
DISTFILES \
	*.c !(config).h *.md !(mkls).sh \
	configure \
	robsd?(-clean|-cross|-crossenv|-kill|-ports|-regress|-rescue) \
	*.5 robsd?(-clean|-config|-cross|-crossenv|-kill|-ports|-regress|-rescue|-stat).[0-9] \
	LICENSE Makefile Makefile.inc \
	tests/*.sh tests/Makefile

cd tests
mkls "$@" \
TESTS \
	!(t|util).sh
