unset DESTDIR RELEASEDIR

rm -rf $X11OBJDIR/* $X11OBJDIR/.*
chown build:wobj "$X11OBJDIR"
chmod 770 "$X11OBJDIR"

cd "$X11SRCDIR"
make bootstrap
make obj
make build
