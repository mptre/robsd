. "${EXECDIR}/util.sh"

unset DESTDIR RELEASEDIR

cleandir "$XOBJDIR"
chown build:wobj "$XOBJDIR"
chmod 770 "$XOBJDIR"

cd "$XSRCDIR"
make bootstrap
make obj
make build
