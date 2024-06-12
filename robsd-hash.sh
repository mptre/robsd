. "${EXECDIR}/util.sh"

config_load <<'EOF'
ROBSDDIR="${robsddir}"
BUILDDIR="${builddir}"
COMMENT="${comment-path}"
RELDIR="${bsd-reldir}"
RELXDIR="${x11-reldir}"
TAGS="${tags-path}"
TMPDIR="${tmp-dir}"
EOF

if [ -e "${RELXDIR}/SHA256" ]; then
	cat "${RELXDIR}/SHA256" >>"${RELDIR}/SHA256"
	rm "${RELXDIR}/SHA256"
fi

if [ -d "${RELXDIR}" ]; then
	find "${RELXDIR}" -type f -exec mv {} "${RELDIR}" \;
	rm -r "${RELXDIR}"
fi

cd "${RELDIR}"

diff_list "${BUILDDIR}" "*.diff" |
while read -r _f; do
	cp "${_f}" .
done

{
	# Set the date to the start of the build.
	_date="$(build_date -b "${BUILDDIR}")"
	date -u -r "${_date}" "+Build date: %s - %+"
	# Include date of the last CVS revision.
	for _dir in $(prev_release); do
		_date="$(cvs_date -b "${BUILDDIR}" -s "$(step_path "${_dir}")")" || continue
		date -u -r "${_date}" "+Build cvs date: %s - %+"
		break
	done
	echo "Build id: ${BUILDDIR##*/}"
	if [ -e "${TAGS}" ]; then
		echo -n "Build tags: "
		xargs <"${TAGS}"
	fi

	if [ -e "${COMMENT}" ]; then
		echo
		cat "${COMMENT}"
	fi
} >BUILDINFO

if step_eval -n cvs "$(step_path "${BUILDDIR}")" 2>/dev/null && ! step_skip; then
	cvs_changelog -t "${TMPDIR}" >CHANGELOG
fi

# Compute missing checksums.
mv SHA256 SHA256.orig
{
	grep -v \
		-e BUILDINFO \
		-e CHANGELOG \
		-e 'install.*' \
		-e '*.diff.*' \
		SHA256.orig || :

	find . -type f \( -name 'BUILDINFO' -o \
			  -name 'CHANGELOG' -o \
			  -name 'install*' -o \
			  -name '*.diff.*' \) |
	sed -e 's,^\./,,' |
	xargs -rt sha256
} | sort >SHA256
rm SHA256.orig
