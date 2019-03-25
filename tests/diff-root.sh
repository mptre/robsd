if testcase "simple prefix"; then
	cat <<-EOF >$TMP1
	Index: kern/kern_descrip.c
	============================================
	RCS file: /cvs/src/sys/kern/kern_descrip.c,v
	EOF
	assert_eq "/usr/src/sys" "$(diff_root -r src "$TMP1")"
fi

if testcase "relative prefix"; then
	cat <<-EOF >$TMP1
	Index: kern_descrip.c
	============================================
	RCS file: /cvs/src/sys/kern/kern_descrip.c,v
	EOF
	assert_eq "/usr/src/sys/kern" "$(diff_root -r src "$TMP1")"
fi

if testcase "complex prefix"; then
	cat <<-EOF >$TMP1
	Index: sys/sys/pool.h
	================================================
	RCS file: /data/src/openbsd/src/sys/sys/pool.h,v
	EOF
	assert_eq "/usr/src" "$(diff_root -r src "$TMP1")"
fi

if testcase "xenocara prefix"; then
	cat <<-EOF >$TMP1
	Index: driver/xf86-input-keyboard/src/bsd_kbd.c
	===================================================================
	RCS file: /cvs/OpenBSD/xenocara/driver/xf86-input-keyboard/src/bsd_kbd.c,v
	EOF
	assert_eq "/usr/xenocara" "$(diff_root -r xenocara "$TMP1")"
fi

if testcase "fallback"; then
	cat <<-EOF >$TMP1
	diff --git distrib/sets/lists/man/mi distrib/sets/lists/man/mi
	index 16b2629ac37..6bab4bfd68f 100644
	--- distrib/sets/lists/man/mi
	+++ distrib/sets/lists/man/mi
	@@ -1526,6 +1526,7 @@
	+./usr/share/man/man4/kubsan.4
	EOF
	assert_eq "/usr/src" "$(diff_root -f /usr/src -r src "$TMP1")"
fi
