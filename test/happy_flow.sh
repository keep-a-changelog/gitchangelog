#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright (C) 2019 Olliver Schinagl <oliver@schinagl.nl>

set -eu

# Support any invocation of/with shunit2
if [ "${0}" = "${0%%shunit2}" ]; then
	"$(command -v shunit2)" "${0}"
	return "${?}"
fi
src_dir="${1%%${1##*/}}"
COMMAND_UNDER_TEST="$(readlink -f "${COMMAND_UNDER_TEST:-${src_dir}/../bin/git_tag_release.sh}")"
shift

FIXTURES="${FIXTURES:-${src_dir}/fixtures/}"

# shellcheck source=test/common.inc.sh
. "${src_dir}/common.inc.sh"

set +eu


oneTimeSetUp()
{
	echo "Setting up '${COMMAND_UNDER_TEST##*/}' test env"


	echo
	echo "================================================================================"
}

oneTimeTearDown()
{
	echo "Tearing down '${COMMAND_UNDER_TEST##*/}' test env"
}

setUp()
{
	echo

	test_git_repo="$(mktemp -d -p "${SHUNIT_TMPDIR}" "test_git_repo.XXXXXX")"
	git_init "${test_git_repo}" "${FIXTURES}/patches/v0"
}

tearDown()
{
	if [ -d "${test_git_repo}" ]; then
		rm -rf "${test_git_repo?}"
	fi

	echo "--------------------------------------------------------------------------------"
}

_testTagv10()
{
	_ver="v1.0"

	git_merge_request "${test_git_repo}" \
	                  "${FIXTURES}/patches/${_ver}" \
	                  "feature/add_initial_application" \
	                  "Feature: Add initial application"
	_expected_output="$(
		cat <<-EOT
			### Added
			- Add initial application
		EOT
	)"
	(
		cd "${test_git_repo}"
		"${COMMAND_UNDER_TEST}" -a \
		                        -m "Release branch for ${_ver}" \
		                        -m "Amazing Amadeus" \
		                        "${_ver}"
		git branch "release/${_ver}"
	)
	assertTrue "Unable to tag ${_ver}" "[ ${?} -eq 0 ]"
	assertEquals "Changelog does not match expected value" \
	             "${_expected_output}" \
	             "$(tail -n "+${CHANGELOG_HEADER_SIZE}" "${test_git_repo}/CHANGELOG.md" | \
	                head -n "$(echo "${_expected_output}" | wc -l)")"
}

_testTagv11()
{
	_testTagv10

	_ver="v1.1"

	git_merge_request "${test_git_repo}" \
	                  "${FIXTURES}/patches/${_ver}" \
	                  "changed/exit_handler" \
	                  "Changed: Ensure proper exit handling"
	_expected_output="$(
		cat <<-EOT
			### Changed
			- Ensure proper exit handling
		EOT
	)"
	(
		cd "${test_git_repo}"
		"${COMMAND_UNDER_TEST}" -a \
		                        -m "Release branch for ${_ver}" \
		                        -m "Baffling Beethoven" \
		                        "${_ver}"
		git branch "release/${_ver}"
	)
	assertTrue "Unable to tag ${_ver}" "[ ${?} -eq 0 ]"
	assertEquals "Changelog does not match expected value" \
	             "${_expected_output}" \
	             "$(tail -n "+${CHANGELOG_HEADER_SIZE}" "${test_git_repo}/CHANGELOG.md" | \
	                head -n "$(echo "${_expected_output}" | wc -l)")"
}

_testHotfix111()
{
	_testTagv11

	_ver="v1.1.1"

	git_add_hotfix "${test_git_repo}" "${FIXTURES}/patches/${_ver}" "release/${_ver%.*}"
	_expected_output="$(
		cat <<-EOT
			### Fixes
			- Fix typo
			- Fix typo
		EOT
	)"
	(
		cd "${test_git_repo}"
		git checkout "release/${_ver%.*}"
		"${COMMAND_UNDER_TEST}" -a \
		                        -m "Critical fix" \
		                        -m "Divinity update" \
		                        "${_ver}"
	)
	assertTrue "Unable to tag ${_ver}" "[ ${?} -eq 0 ]"
	assertEquals "Changelog does not match expected value" \
	             "${_expected_output}" \
	             "$(tail -n "+${CHANGELOG_HEADER_SIZE}" "${test_git_repo}/CHANGELOG.md" | \
	                head -n "$(echo "${_expected_output}" | wc -l)")"

	if [ -f "${test_git_repo}/CHANGELOG.md" ]; then
		echo "################ CHANGELOG.md #################################"
		cat "${test_git_repo}/CHANGELOG.md"
		echo "###############################################################"
	fi

	git_add_hotfix "${test_git_repo}" "${FIXTURES}/patches/${_ver}" "master"
}

_testTagv12()
{
	_testHotfix111

	_ver="v1.2"

	git_merge_request "${test_git_repo}" \
	                  "${FIXTURES}/patches/${_ver}" \
	                  "changes/no_changes" \
	                  "Not keep-a-changelog tag"
	_expected_output="$(
		cat <<-EOT
			No changes
		EOT
	)"
	(
		cd "${test_git_repo}"
		"${COMMAND_UNDER_TEST}" -a \
		                        -m "Release branch for ${_ver}" \
		                        -m "Carismic Chopin" \
		                        "${_ver}"
		git branch "release/${_ver}"
	)
	assertTrue "Unable to tag ${_ver}" "[ ${?} -eq 0 ]"
	assertEquals "Changelog does not match expected value" \
	             "${_expected_output}" \
	             "$(tail -n "+${CHANGELOG_HEADER_SIZE}" "${test_git_repo}/CHANGELOG.md" | \
	                head -n "$(echo "${_expected_output}" | wc -l)")"
}

_testTagv13()
{
	_testTagv12

	_ver="v1.3"

	git_merge_request "${test_git_repo}" \
	                  "${FIXTURES}/patches/${_ver}" \
	                  "security/impeccable_security" \
	                  "Security: Impeccable security"
	_expected_output="$(
		cat <<-EOT
			### Security
			- Impeccable security
		EOT
	)"
	(
		cd "${test_git_repo}"
		"${COMMAND_UNDER_TEST}" -a \
		                        -m "Release branch for ${_ver}" \
		                        -m "Dubious Debussy" \
		                        "${_ver}"
		git branch "release/${_ver}"
	)
	assertTrue "Unable to tag ${_ver}" "[ ${?} -eq 0 ]"
	assertEquals "Changelog does not match expected value" \
	             "${_expected_output}" \
	             "$(tail -n "+${CHANGELOG_HEADER_SIZE}" "${test_git_repo}/CHANGELOG.md" | \
	                head -n "$(echo "${_expected_output}" | wc -l)")"
}

_testTagv14()
{
	_testTagv13

	_ver="v1.4"

	git_merge_request "${test_git_repo}" \
	                  "${FIXTURES}/patches/${_ver}_a" \
	                  "fixes/shift_args" \
	                  "Fix: Shift argument count"
	git_merge_request "${test_git_repo}" \
	                  "${FIXTURES}/patches/${_ver}_b" \
	                  "add/accept_an_argument" \
	                  "Add: Accept arguments"
	git_merge_request "${test_git_repo}" \
	                  "${FIXTURES}/patches/${_ver}_c" \
	                  "fix/change_greeting_properly" \
	                  "Fix: Sign off greeting properly done"
	git_merge_request "${test_git_repo}" \
	                  "${FIXTURES}/patches/${_ver}_d" \
	                  "security/superuser_not_root" \
	                  "security: Use super-user not root"
	_expected_output="$(
		cat <<-EOT
			### Security
			- Use super-user not root

			### Fixes
			- Sign off greeting properly done
			- Shift argument count

			### Added
			- Accept arguments
		EOT
	)"
	(
		cd "${test_git_repo}"
		"${COMMAND_UNDER_TEST}" -a \
		                        -m "Release branch for ${_ver}" \
		                        -m "Ecliptic Elgar" \
		                        "${_ver}"
		git branch "release/${_ver}"
	)
	assertTrue "Unable to tag ${_ver}" "[ ${?} -eq 0 ]"
	assertEquals "Changelog does not match expected value" \
	             "${_expected_output}" \
	             "$(tail -n "+${CHANGELOG_HEADER_SIZE}" "${test_git_repo}/CHANGELOG.md" | \
	                head -n "$(echo "${_expected_output}" | wc -l)")"
}

testHappyFlow()
{
	_testTagv14

	if [ -f "${test_git_repo}/CHANGELOG.md" ]; then
		echo "################ CHANGELOG.md #################################"
		cat "${test_git_repo}/CHANGELOG.md"
		echo "###############################################################"
	fi
}
