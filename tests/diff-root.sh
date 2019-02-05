if testcase "simple prefix"; then
	cat <<-EOF >$TMP1
	Index: kern/kern_descrip.c
	============================================
	RCS file: /cvs/src/sys/kern/kern_descrip.c,v
	EOF
	assert_eq "/usr/src/sys" "$(diff_root "$TMP1")"
fi

if testcase "relative prefix"; then
	cat <<-EOF >$TMP1
	Index: kern_descrip.c
	============================================
	RCS file: /cvs/src/sys/kern/kern_descrip.c,v
	EOF
	assert_eq "/usr/src/sys/kern" "$(diff_root "$TMP1")"
fi

if testcase "complex prefix"; then
	cat <<-EOF >$TMP1
	Index: sys/sys/pool.h
	================================================
	RCS file: /data/src/openbsd/src/sys/sys/pool.h,v
	EOF
	assert_eq "/usr/src" "$(diff_root "$TMP1")"
fi
