. "${EXECDIR}/util.sh"

# duration pattern
duration() {
	local _pattern

	_pattern="$1"; : "${_pattern:?}"
	grep -m 1 "$_pattern" | awk '{print $NF}' | sed 's/\..*//'
}

config_load <<'EOF'
CHROOT="${chroot}"
PORTSDIR="${ports-dir}"
PORTS="${ports}"
EOF

PATH="${CHROOT}${PORTSDIR}/infrastructure/bin:${PATH}"

_arch="$(machine)"

xargs -t rm -rf <<EOF
${CHROOT}${PORTSDIR}/logs/${_arch}
${CHROOT}${PORTSDIR}/distfiles/build-stats/${_arch}
EOF

_ncpu="$(sysctl -n hw.ncpuonline)"
# shellcheck disable=SC2086
dpb -c -B "$CHROOT" -j "$_ncpu" -p "$_ncpu" $PORTS

_fail=0
for _p in $PORTS; do
	_id="$(step_id "$_p")"
	_dst="${BUILDDIR}/$(log_id -b "$BUILDDIR" -n "$_p" -s "$_id")"
	_log="${CHROOT}${PORTSDIR}/logs/${_arch}/paths/${_p}.log"
	if [ -e "$_log" ]; then
		cp "$_log" "$_dst"
		_t0="$(duration '^>>> Running ' <"$_log")"
		_t1="$(duration '^>>> Ended ' <"$_log")"
		_exit="$(! grep -q '^Error: job failed ' "$_log"; echo $?)"
		[ "$_exit" -eq 0 ] || _fail=1
		HOOK="" step_end -d "$((_t1 - _t0))" -e "$_exit" -l "$_dst" \
			-n "$_p" -s "$_id" "${BUILDDIR}/steps"
	elif grep "!: ${_p} " "/${CHROOT}${PORTSDIR}/logs/${_arch}/engine.log" \
	     >"$_dst"
	then
		_fail=1
		HOOK="" step_end -d 0 -e 1 -l "$_dst" \
			-n "$_p" -s "$_id" "${BUILDDIR}/steps"
	fi
done

exit "$_fail"
