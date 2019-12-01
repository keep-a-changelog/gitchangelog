#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright (C) 2018 Olliver Schinagl <oliver@schinagl.nl>

set -eu

REQUIRED_COMMANDS="
	[
	command
	cp
	dd
	echo
	exit
	getopts
	head
	printf
	sed
	seq
	set
	shift
	shunit2
	stat
	tac
	tail
	test
	tr
	unlink
"


usage()
{
	echo "Usage: ${0} [OPTIONS]"
	echo "A simple test script to verify the environment has all required tools."
	echo "    -h  Print usage"
}

check_requirements()
{
	for _cmd in ${REQUIRED_COMMANDS}; do
		if ! _test_result="$(command -V "${_cmd}")"; then
			_test_result_fail="${_test_result_fail:-}${_test_result}\n"
		else
			_test_result_pass="${_test_result_pass:-}${_test_result}\n"
		fi
	done

	echo "Passed tests:"
	# shellcheck disable=SC2059  # Interpret \n from variable
	printf "${_test_result_pass:-none\n}"
	echo
	echo "Failed tests:"
	# shellcheck disable=SC2059  # Interpret \n from variable
	printf "${_test_result_fail:-none\n}"
	echo

	if [ -n "${_test_result_fail:-}" ]; then
		echo "Self-test failed, missing dependencies."
		exit 1
	fi
}

main()
{
	while getopts ":h" options; do
    		case "${options}" in
    		h)
            		usage
            		exit 0
            		;;
    		:)
            		echo "Option -${OPTARG} requires an argument."
            		exit 1
            		;;
    		?)
            		echo "Invalid option: -${OPTARG}"
            		exit 1
            		;;
    		esac
	done
	shift "$((OPTIND - 1))"

	check_requirements

	echo "All Ok"
}

main "${@}"

exit 0
