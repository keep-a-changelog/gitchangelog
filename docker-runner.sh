#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright (C) 2019 Olliver Schinagl <oliver@schinagl.nl>

set -eu

WORKDIR="${WORKDIR:-/workdir}"
REQUIRED_COMMANDS="
	[
	basename
	command
	docker
	echo
	eval
	exit
	getopts
	hostname
	printf
	pwd
	readlink
	test
"


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
	echo "Usage: ${0} [COMMAND] [ARGUMENTS]"
	echo "Docker wrapper and helper script."
	echo "The following environment variables can be set to pass additional parameters"
	echo "    [CI_REGISTRY_IMAGE] to change the docker container to build in"
	echo "    [OPT_DOCKER_ARGS] optional arguments to supply to the docker run command"
	echo
	echo "When symlinking using the name of an existing script, prefixed with 'docker_'"
	echo "run that inside the container. E.g. docker_run_test.sh runs run_test.sh inside the container."
	echo
	echo "Without any commands and without a symlink will open a console in the container."
}

init()
{
	src_file="$(readlink -f "${0}")"
	src_dir="${src_file%%${src_file##*/}}"
	src_name="$(basename "${0}")"

	# shellcheck disable=SC2021  # Busybox tr is non-posix without classes
	CI_REGISTRY_IMAGE="${CI_REGISTRY_IMAGE:-$(basename "$(pwd | tr '[A-Z]' '[a-z]')"):latest}"

	if ! docker pull "${CI_REGISTRY_IMAGE}" 2> "/dev/null"; then
		e_warn "Unable to pull docker image '${CI_REGISTRY_IMAGE}', building locally instead."
		if ! docker build --pull -t "${CI_REGISTRY_IMAGE}" "${src_dir}"; then
			e_warn "Failed to build local container, attempting existing container."
		fi
	fi

	if ! docker inspect --type image "${CI_REGISTRY_IMAGE}" 1> "/dev/null"; then
		e_err "Container '${CI_REGISTRY_IMAGE}' not found, cannot continue."
		exit 1
	fi

	opt_docker_args="-v '$(pwd):${WORKDIR}' -e 'SHUNIT_COLOR=${SHUNIT_COLOR:-always}' ${OPT_DOCKER_ARGS:-}"
}

docker_run()
{
	if [ "${src_name#docker_}" != "${src_name}" ]; then
		_argv0="./${src_name#docker_}"
	else
		usage
		_argv0="/bin/sh"
		echo "Starting shell inside container"
	fi

	eval docker run \
	            --rm \
	            -h "$(hostname)" \
	            -i \
	            -t \
	            -w "${WORKDIR}" \
	            "${opt_docker_args:-}" \
	            "${CI_REGISTRY_IMAGE}" \
	            "${_argv0:-}" "${@}"
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

	if [ -n "${_test_result_fail:-}" ]; then
		e_err "Self-test failed, missing dependencies."
		echo "======================================="
		echo "Passed tests:"
		# shellcheck disable=SC2059  # Interpret \n from variable
		printf "${_test_result_pass:-none\n}"
		echo "---------------------------------------"
		echo "Failed tests:"
		# shellcheck disable=SC2059  # Interpret \n from variable
		printf "${_test_result_fail:-none\n}"
		echo "======================================="
		exit 1
	fi
}

main()
{
	_start_time="$(date "+%s")"

	check_requirements
	init
	docker_run "${@}"

	echo "Ran docker container for $(($(date "+%s") - _start_time)) seconds"
}

main "${@}"

exit 0
