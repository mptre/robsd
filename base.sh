unset DESTDIR RELEASEDIR

chown build:wobj "$BSDOBJDIR"
chmod 770 "$BSDOBJDIR"

cd "$BSDSRCDIR"
make obj
make build
