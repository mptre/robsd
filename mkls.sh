export LC_ALL=C

mkls "$@" \
SRCS \
	!(fuzz-*|robsd-*).c \
	$(find libks -type f -name '*.c' -exec basename {} \;) \
	-- \
KNFMT \
	!(compat-*).c !(config).h \
	-- \
CLANGTIDY \
	!(config|compat-*).h !(compat-*).c \
	-- \
CPPCHECK \
	!(compat-*).c \
	-- \
SCRIPTS \
	!(mkls).sh \
	-- \
DISTFILES \
	*.c !(config).h libks/*.[ch] *.md !(mkls).sh \
	configure \
	robsd?(-clean|-cross|-crossenv|-kill|-ports|-regress|-rescue) \
	*.5 robsd?(-clean|-config|-cross|-crossenv|-kill|-ports|-regress|-regress-html|-regress-log|-rescue|-stat|-step).[0-9] \
	LICENSE Makefile Makefile.inc \
	tests/*.sh tests/Makefile

cd tests
mkls "$@" \
TESTS \
	!(t|util).sh
