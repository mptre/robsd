unset DESTDIR

chown build:wobj "$BSDOBJDIR"
chmod 770 "$BSDOBJDIR"

cd "$BSDSRCDIR"
make obj
make build

sysmerge
cd /dev && ./MAKEDEV all
