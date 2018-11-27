unset DESTDIR RELEASEDIR

cd "$BSDSRCDIR"
make obj
make build
