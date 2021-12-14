. "${EXECDIR}/util.sh"

# duration pattern
duration() {
	local _pattern

	_pattern="$1"; : "${_pattern:?}"
	grep -m 1 "$_pattern" | awk '{print $NF}' | sed 's/\..*//'
}

PATH="${CHROOT}${PORTSDIR}/infrastructure/bin:${PATH}"

_arch="$(machine)"

_parallel=""
if [ "$MAKE_JOBS" -gt 0 ]; then
	_parallel="${MAKE_JOBS:+"-j ${MAKE_JOBS} -p ${MAKE_JOBS}"}"
fi
unset MAKE_JOBS

xargs -t rm -rf <<EOF
${CHROOT}${PORTSDIR}/logs/${_arch}
${CHROOT}${PORTSDIR}/distfiles/build-stats/${_arch}
EOF

# shellcheck disable=SC2086
dpb -c -B "$CHROOT" $_parallel $PORTS

_fail=0
for _p in $PORTS; do
	_src="${CHROOT}${PORTSDIR}/logs/${_arch}/paths/${_p}.log"
	[ -e "$_src" ] || continue

	_id="$(step_id "$_p")"
	_dst="${BUILDDIR}/$(log_id -b "$BUILDDIR" -n "$_p" -s "$_id")"
	cp "$_src" "$_dst"

	_t0="$(duration '^>>> Running ' <"$_src")"
	_t1="$(duration '^>>> Ended ' <"$_src")"
	_exit="$(! grep -q '^Error: job failed ' "$_src"; echo $?)"
	[ "$_exit" -eq 0 ] || _fail=1
	HOOK="" step_end -d "$((_t1 - _t0))" -e "$_exit" -l "$_dst" \
		-n "$_p" -s "$_id" "${BUILDDIR}/steps"
done

exit "$_fail"
