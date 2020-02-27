default_config() {
	cat <<-EOF
	CVSROOT=example.com:/cvs
	CVSUSER=nobody
	DESTDIR=/var/empty
	DISTRIBHOST=example.com
	DISTRIBPATH=/var/empty
	DISTRIBUSER=nobody
	EOF
}

if testcase "missing source diff"; then
	{
		default_config
		echo "BSDDIFF=\"${TSHDIR}/src.diff.1 ${TSHDIR}/src.diff.2\""
	} >"$TMP1"
	touch "${TSHDIR}/src.diff.1"
	config_load "$TMP1"
	assert_eq "${TSHDIR}/src.diff.1" "$BSDDIFF"
fi

if testcase "missing xenocara diff"; then
	{
		default_config
		echo "XDIFF=\"${TSHDIR}/xenocara.diff.1 ${TSHDIR}/xenocara.diff.2\""
	} >"$TMP1"
	touch "${TSHDIR}/xenocara.diff.2"
	config_load "$TMP1"
	assert_eq "${TSHDIR}/xenocara.diff.2" "$XDIFF"
fi

if testcase "no diffs"; then
	default_config >"$TMP1"
	config_load "$TMP1"
	assert_eq "" "$BSDDIFF"
	assert_eq "" "$XDIFF"
fi
