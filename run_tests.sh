#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright (C) 2019 Olliver Schinagl <oliver@schinagl.nl>

set -eu


e_err()
{
	>&2 echo "ERROR: ${*}"
}

e_warn()
{
	echo "WARN: ${*}"
}

usage()
{
	echo "Usage: ${0} [OPTIONS]"
	echo "Run this repositories tests."
	echo "    -h  Print usage"
}

run_tests()
{
	if [ "${#}" -ge 1 ]; then
		for _test_script in "${@}"; do
			echo "Running shunit2 on '${_test_script}'"
			shunit2 "${_test_script}"
		done
	else
		find 'test/' \
		     -path '*fixtures*' -prune -o \
		     -type f -perm '/a+x' -iname '*.sh' | while read -r _test_script; do
			if [ ! -f "${_test_script}" ]; then
				continue
			fi
			echo "Running shunit2 on '${_test_script}'"
			shunit2 "${_test_script}"
		done
	fi
}

main()
{
	_start_time="$(date "+%s")"

	while getopts ":h" options; do
		case "${options}" in
		h)
			usage
			exit 0
			;;
		:)
			e_err "Option -${OPTARG} requires an argument."
			exit 1
			;;
		?)
			e_err "Invalid option: -${OPTARG}"
			exit 1
			;;
		esac
	done
	shift "$((OPTIND - 1))"

	./buildenv_check.sh
	run_tests "${@}"

	echo "Ran tests in $(($(date "+%s") - _start_time)) seconds"
}

main "${@}"

exit 0
