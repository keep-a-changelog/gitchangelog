#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright (C) 2019 Olliver Schinagl <oliver@schinagl.nl>


set -eu

# shellcheck disable=SC2034  # Unused variables are used when sourced
CHANGELOG_HEADER_SIZE=11

set +eu

## random_int_range - generate a random number between min and max
# min:	minimum random value
# max:	maximum random value
random_int_range()
{
	_min="${1?}"
	_max="${2?}"

	if ! shuf -n 1 -i "${_min}"-"${_max}"; then
		fail "Unable to generate random number"
		return
	fi
}

## random_int - generate a random number between 0 and max
# max:	maximum random value
random_int()
{
	_max="${1?}"

	random_int_range 0 "${_max}"
}


## git_add_patches - add patches to a git repository
# repo:		repository to add patches onto
# patch_src:	directory to use .patch files from
git_add_patches()
{
	_repo="${1:?Missing argument to function}"
	_patch_src="$(readlink -f "${2:?Missing argument to function}")"

	(
		cd "${_repo}" || fail "Unable to go to '${_repo}'"

		for _patch in "${_patch_src}/"*".patch"; do
			if [ -z "${_patch}" ]; then
				continue
			fi

			git am "${_patch}"
		done
	)
}

## git_add_hotfix - add hotfixes to a (release) branch
# repo:			repository to add patches onto
# patch_src:		directory to use .patch files from
# release_branch:	release branch to add hotfixes too
git_add_hotfix()
{
	_repo="${1:?Missing argument to function}"
	_patch_src="$(readlink -f "${2:?Missing argument to function}")"
	_release_branch="${3?Missing argument to function}"

	(
		cd "${_repo}" || fail "Unable to go to '${_repo}'"

		git checkout "${_release_branch}"
		git_add_patches "${_repo}" \
		                "${_patch_src}"
		git checkout master
	)
}

## git_merge_request - create a feature branch, and merge it into master
# repo:			repository to add patches onto
# patch_src:		directory to use .patch files from
# branch_name:		name of the feature branch to merge
# merge_message, ...:	optional message(s) for the merge log
git_merge_request()
{
	_repo="${1:?Missing argument to function}"
	_patch_src="$(readlink -f "${2?Missing argument to function}")"
	_branch_name="${3?Missing argument to function}"
	shift 3

	_merge_message="-m \"Merge branch '${_branch_name}' into 'master'\" "
	for _msg in "${@}"; do
		_merge_message="${_merge_message}-m '${_msg}' "
	done

	(
		cd "${_repo}" || fail "Unable to go to '${_repo}'"

		git checkout -b "${_branch_name}"
		git_add_patches "${_repo}" \
		                "${_patch_src}"
		git checkout master
		eval git merge --no-ff --no-log --no-edit \
		               "${_merge_message}" \
		               "${_branch_name}"
		git branch --delete --force "${_branch_name}"
	)
}

## git_init - initialize repo from template
# repo:			repository to add patches onto
# patch_src:		directory to use .patch files from
# git_template:		git template directory
git_init()
{
	_repo="${1:?Missing argument to function}"
	_patch_src="$(readlink -f "${2:?Missing argument to function}")"
	_git_template="${3:-}"

	git init ${_git_template:+--template "${FIXTURES}/template_test_git_repo/"} "${_repo}"

	(
		cd "${_repo}" || fail "Unable to go to '${_repo}'"

		git config user.email "test@example.com"
		git config user.name "Test User"

		if [ -n "${_patch_src}" ]; then
			git_add_patches "${_repo}" \
			                "${_patch_src}"
		else
			touch .gitignore
			git add .gitignore
			git commit --message "Initial commit"
		fi

		git tag \
		    --annotate \
		    --message "Initial marker" \
		    --message "Marks the start of the project." \
		    "v0"
	)
}
