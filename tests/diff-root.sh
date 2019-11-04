BSDSRCDIR="$TSHDIR"
XSRCDIR="$TSHDIR"

if testcase "simple prefix"; then
	install -D /dev/null "${BSDSRCDIR}/sys/kern/kern_descrip.c"
	cat <<-EOF >$TMP1
	Index: kern/kern_descrip.c
	============================================
	RCS file: /cvs/src/sys/kern/kern_descrip.c,v
	EOF
	assert_eq "${BSDSRCDIR}/sys" "$(diff_root -d "$BSDSRCDIR" "$TMP1")"
fi

if testcase "relative prefix"; then
	install -D /dev/null "${BSDSRCDIR}/sys/kern/kern_descrip.c"
	cat <<-EOF >$TMP1
	Index: kern_descrip.c
	============================================
	RCS file: /cvs/src/sys/kern/kern_descrip.c,v
	EOF
	assert_eq "${BSDSRCDIR}/sys/kern" "$(diff_root -d "$BSDSRCDIR" "$TMP1")"
fi

if testcase "complex prefix"; then
	install -D /dev/null "${BSDSRCDIR}/sys/sys/pool.h"
	cat <<-EOF >$TMP1
	Index: sys/sys/pool.h
	================================================
	RCS file: /data/src/openbsd/src/sys/sys/pool.h,v
	EOF
	assert_eq "$BSDSRCDIR" "$(diff_root -d "$BSDSRCDIR" "$TMP1")"
fi

if testcase "xenocara prefix"; then
	install -D /dev/null "${XSRCDIR}/driver/xf86-input-keyboard/src/bsd_kbd.c"
	cat <<-EOF >$TMP1
	Index: driver/xf86-input-keyboard/src/bsd_kbd.c
	===================================================================
	RCS file: /cvs/OpenBSD/xenocara/driver/xf86-input-keyboard/src/bsd_kbd.c,v
	EOF
	assert_eq "$XSRCDIR" "$(diff_root -d "$XSRCDIR" "$TMP1")"
fi

if testcase "fallback"; then
	cat <<-EOF >$TMP1
	Index: kern/kern_descrip.c
	============================================
	RCS file: /cvs/src/sys/kern/kern_descrip.c,v
	EOF
	assert_eq "$BSDSRCDIR" "$(diff_root -d "$BSDSRCDIR" "$TMP1")"
fi
