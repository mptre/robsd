cd "$RELEASEDIR"
rm -f index.txt SHA256{,.sig}
sha256 -h SHA256 -- *

if [ -n "$SIGNIFY" ]; then
	signify -Se -s "$SIGNIFY" -m SHA256
fi

ls -nT -- * >index.txt

su "$DISTRIBUSER" \
	-c "/usr/local/bin/rsync -prt --del ${RELEASEDIR} ${DISTRIBHOST}:${DISTRIBPATH}"
