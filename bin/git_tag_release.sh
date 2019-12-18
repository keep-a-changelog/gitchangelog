#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright (C) 2019 Olliver Schinagl <oliver@schinagl.nl>

set -eu

CHANGELOG="${CHANGELOG:-CHANGELOG.md}"
DEF_BRANCH="${DEF_BRANCH:-master}"
DEF_BRANCH_PREFIX="${DEF_BRANCH_PREFIX:-release}"
TAG_PREFIX="${TAG_PREFIX:-v}"


usage()
{
	echo "Usage: ${0} [<arguments to git tag>]"
	echo "Tool to create release tags and update the Changelog  file '${CHANGELOG}'. [CHANGELOG]"
	echo "Decisions are made based in reference to the branch '${DEF_BRANCH}'. [DEF_BRANCH]"
	echo "Tags are expected to follow semver and can have a tag prefix '${TAG_PREFIX}'. [TAG_PREFIX]"
	echo "Release branches are prefixed using '${DEF_BRANCH_PREFIX}/<tag>'. [DEF_BRANCH_PREFIX]"
	echo
	echo "The script itself does not take any arguments, but passes those along to 'git tag'."
	echo "Without any arguments a tag is expected to already exist and only the changelog is updated."
	echo "All options can also be passed in environment variables (listed between [BRACKETS])."
	echo
	echo "Create tags as would be done normally, create release-branch tags .0 tags"
	echo
	echo "An important note about signed tags, as tags need to be re-written"
	echo "due to the inclusion of the changelog, only users that can sign tags"
	echo "can update repositories with signed tags."
}

recreate_tag()
{
	_changelog="${1:?}"

	_git_tag_msg="$(git tag --format="%(contents:subject)" --list "${git_tag}")"
	_git_tag_body="$(git tag --format="%(contents:body)" --list "${git_tag}")"
	if [ -n "${_git_tag_body}" ]; then
		_git_tag_msg="$(printf "%s\n\n%s" "${_git_tag_msg:-}" "${_git_tag_body}")"
	fi

	_git_tag_msg="$(
		cat <<-EOT
			${_git_tag_msg}

			${_changelog}
		EOT
	)"

	echo "Appending changelog to tag:"
	echo "---------------------------"
	echo "${_changelog}"
	echo "---------------------------"

	_git_tag_signature="$(git tag --format="%(contents:signature)" --list "${git_tag}")"
	if [ -n "${_git_tag_signature}" ]; then
		echo "Signature on current tag found, re-signing required."
		_git_tag_resign="true"
	fi
	git tag --annotate --force --message="${_git_tag_msg}" ${_git_tag_resign+--sign} "${git_tag}"
}

update_changelog()
{
	_changelog="${1:?}"
	_changelog_header="$(
		cat <<-EOT
			# Changelog
			All notable changes to this project will be documented in this file.

			The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
			and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


			**NOTE:** DO NOT EDIT! This changelog is automatically generated. See the README.md file for more information.
		EOT
	)"
	# Tail needs + 1, so add a \n to get an extra line
	_changelog_header_size="$(printf "%s\n\n" "${_changelog_header}" | wc -l)"

	if [ -z "${_changelog}" ]; then
		return
	fi

	if [ -f "${CHANGELOG}" ]; then
		mv "${CHANGELOG}" "${CHANGELOG}.orig"
		trap 'mv "${CHANGELOG}.orig" "${CHANGELOG}"' EXIT
	fi

	if [ -f "${CHANGELOG}.orig" ] && \
	   [ "$(wc -l < "${CHANGELOG}.orig")" -ge "${_changelog_header_size}" ]; then
		_changelog="${_changelog}$(printf "\n" && tail -n "+${_changelog_header_size}" "${CHANGELOG}.orig")"
	fi
	{
		echo "${_changelog_header}"
		echo
		echo "${_changelog}"
	} > "${CHANGELOG}"
	git add "${CHANGELOG}"
	if git diff-index --quiet "HEAD" -- "${CHANGELOG}"; then
		echo "No changes for '${CHANGELOG}', done"
		exit 0
	fi
	echo "Updating '${CHANGELOG}'"
	git commit --message="Changelog: Auto-generate new '${CHANGELOG}" --no-edit
	trap - EXIT
	if [ -f "${CHANGELOG}.orig" ]; then
		rm "${CHANGELOG}.orig"
	fi
}

generate_hotfix_changelog()
{
	_release_header="## [${git_tag}] - ${git_tag_date}"
	_git_release_hotfixes="$(git log \
	                            --no-merges \
	                            --pretty=format:"- %s" "${git_previous_tag}"...HEAD | \
	                        sed '/^- Changelog:.*/d')"

	if [ -z "${_git_release_hotfixes:-}" ]; then
		changelog="$(
			cat <<-EOT
				${_release_header}
				No changes
			EOT
		)"

		return
	fi

	changelog="$(
		cat <<-EOT
			${_release_header}
			### Fixes
			${_git_release_hotfixes}
		EOT
	)"
}

generate_release_changelog()
{
	_release_header="## [${git_tag}.0] - ${git_tag_date}"

	for _git_hash in $(git log \
	                       --merges \
	                       --pretty=tformat:"%H" "${git_previous_tag}"...HEAD); do
		_git_log_entry="$(git show --no-patch --pretty=format:"%b" "${_git_hash}" | head -n 1 | sed 's|:[[:space:]]*|:|')"

		case ${_git_log_entry} in
		[Ss]ecurity*:*)
			_git_security_entries="$(
				cat <<-EOT
					${_git_security_entries:-### Security}
					- ${_git_log_entry#*:}
				EOT
			)"
			;;
		[Ff]ix*:* | [Ff]ixe[sd]*:* | [Bb]ugfix*:*)
			_git_bugfix_entries="$(
				cat <<-EOT
					${_git_bugfix_entries:-### Fixes}
					- ${_git_log_entry#*:}
				EOT
			)"
			;;
		[Rr]emove[sd]*:*)
			_git_removed_entries="$(
				cat <<-EOT
					${_git_removed_entries:-### Removed}
					- ${_git_log_entry#*:}
				EOT
			)"
			;;
		[Dd]eprecate[sd]*:*)
			_git_deprecated_entries="$(
				cat <<-EOT
					${_git_deprecated_entries:-### Deprecated}
					- ${_git_log_entry#*:}
				EOT
			)"
			;;
		[Cc]hange[sd]*:*)
			_git_changed_entries="$(
				cat <<-EOT
					${_git_changed_entries:-### Changed}
					- ${_git_log_entry#*:}
				EOT
			)"
			;;
		[Aa]dd*:* | [Ff]eature*:*)
			_git_added_entries="$(
				cat <<-EOT
					${_git_added_entries:-### Added}
					- ${_git_log_entry#*:}
				EOT
			)"
			;;
		*)
			echo "Not worthy of a changelog entry:"
			echo "'${_git_log_entry}'"
			;;
		esac
	done

	if [ -z "${_git_security_entries:-}" ] && \
	   [ -z "${_git_bugfix_entries:-}" ] && \
	   [ -z "${_git_removed_entries:-}" ] && \
	   [ -z "${_git_deprecated_entries:-}" ] && \
	   [ -z "${_git_changed_entries:-}" ] && \
	   [ -z "${_git_added_entries:-}" ]; then
		changelog="$(
			cat <<-EOT
				${_release_header}
				No changes
			EOT
		)"

		return
	fi

	# Heredoc quirkiness ahead, ensure all white-space/new-lines are proper
	changelog="$(
		cat <<-EOT
			${_release_header}
${_git_security_entries:+${_git_security_entries}

}\
${_git_bugfix_entries:+${_git_bugfix_entries}

}\
${_git_removed_entries:+${_git_removed_entries}

}\
${_git_deprecated_entries:+${_git_deprecated_entries}

}\
${_git_changed_entries:+${_git_changed_entries}

}\
${_git_added_entries:-}
		EOT
	)"
}

git_tag_release()
{
	git_branch="$(git rev-parse --abbrev-ref HEAD)"
	if [ "${git_branch}" != "${DEF_BRANCH}" ] && \
	   [ -z "$(echo "${git_branch}" | sed -n '/^'"${DEF_BRANCH_PREFIX}"'\/'"${TAG_PREFIX}"'[[:digit:]]\+\(\.[[:digit:]]\+\)\+.*$/p')" ]; then
		echo "Release tags are only allowed on the default branch '${DEF_BRANCH}'"
		echo "and on stable release branches (${DEF_BRANCH_PREFIX}/${TAG_PREFIX}<semver>[/\$arch|release])."
		exit 1
	fi

	git_tag="$(git describe --exact-match --match "${TAG_PREFIX}[0-9]*" HEAD 2> "/dev/null" || true)"
	if [ -n "$(echo "${git_tag:-}" | sed -n '/^.*'"${TAG_PREFIX}"'[[:digit:]]\+\(\.[[:digit:]]\+\)\+\(-rc[[:digit:]]\+\)\?$/p')" ] && \
	   [ -z "$(echo "${git_tag:-}" | sed -n '/^.*'"${TAG_PREFIX}"'[[:digit:]]\+\(\.[[:digit:]]\+\)\+\(-rc[[:digit:]]\+\)$/p')" ]; then
		echo "Current 'HEAD' is already properly tagged."
		echo "Only release candidate tags (-rc) can be re-tagged."
		exit 1
	fi

	if [ "${#}" -ne 0 ]; then
		git tag "${@}"
	fi

	if ! git_tag="$(git describe --exact-match --match "${TAG_PREFIX}[0-9]*" HEAD 2> "/dev/null")"; then
		echo "Current 'HEAD' is not an annotated tag, nothing to do."
		exit 0
	fi

	while
		git_previous_tag="$(git describe --abbrev=0 --match "${TAG_PREFIX}[0-9]*" "${git_previous_tag:-HEAD~1}")"
		[ "${git_previous_tag%%-rc*}" != "${git_previous_tag}" ]; do
			git_previous_tag="${git_previous_tag}~1"
	done
	if [ -z "${git_previous_tag:-}" ]; then
		echo "Unable to find previous annotated tag."
		echo "On new projects, tag v0 on the last scaffolding commit'."
		echo "If so desired, after generating the changelog and first real tag"
		echo "The tag could be deleted before pushing."
		exit 1
	fi

	git_tag_date="$(git tag \
	                    --format="%(taggerdate:short)" \
	                    --list "${git_tag}")"

	# Get branch history since last release (e.g all merge commits since v1.0)
	# when tagging a new release branch.
	if [ "$(echo "${git_tag}" | sed 's|^'"${TAG_PREFIX}"'[[:digit:]]\+\.[[:digit:]]\+$||g')" != "${git_tag}" ] ; then
		generate_release_changelog
	# Get branch history since the first commit of the release branch, except
	# for the first tag (v1.0.0), as that is really the release branch log.
	elif [ "$(echo "${git_tag}" | sed 's|^.*'"${TAG_PREFIX}"'[[:digit:]]\+\(\.[[:digit:]]\+\)\{2,\}$||g')" != "${git_tag}" ] && \
	     [ "${git_tag##*.}" -ne 0 ] 2> "/dev/null"; then
		generate_hotfix_changelog
	fi

	if [ -n "${changelog:-}" ]; then
		update_changelog "${changelog}"
		recreate_tag "${changelog}"
	fi
}

main()
{
	if [ "${1:-}" = '-h' ] || [ "${1:-}" = '--help' ]; then
		git tag "${1}" || true
		usage
		exit 0
	fi

	git_tag_release "${@}"
}

main "${@}"

exit 0
