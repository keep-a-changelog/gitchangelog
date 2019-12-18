# Git Changelog
Tagging releases can be non-trivial, as is keeping a changelog. This project
attempts to leverage the defined format of [Keep-a-Changelog](https://keepachangelog.com)
whilst making use of auto-generation of the Changelog.

Note that using this tool is optional and not required per specification.

## IMPORTANT NOTICE

**While automated changelog generation works great, it does require
great _discipline_ from all users. While manually updating and changing the
changelog is an option, it does defy the purpose of this tool.**

## Using this repository
This repository contains a script, `git_tag_release.sh` and a convenience docker
container to use the script from. Both can be used to generate a CHANGELOG.md
file from.

### Tagging and release script
The script `git_tag_release.sh` takes a properly tagged tree, and generates or
updates a **CHANGELOG.md** file. The actual file can be changed using the
environment variable `CHANGELOG`.

The changelog generation is based on merges put into the **master** branch. This
default can be changed using the environment variable `DEF_BRANCH`.

Hotfix/patch changelog generation is performed based on branches that are
prefixed with **release**. This default can be changed using the environment
variable `DEF_BRANCH_PREFIX`.

Tags are expected to follow [semver](https://semver.org) prefixed with the
character **v**.  This default can be changed using the environment variable
`TAG_PREFIX`.

For added convenience, the script also wraps around the `git tag` command, as
if not almost always, creating a tag, involves updating the changelog and vice
versa. Thus to both tag and update the changelog, just run
`git_tag_release.sh -a -s v1.0` for example to create the tag annotated signed
tag 'v1.0' and update the changelog accordingly.

It should be important to note, that the tag will be re-set after adding the
changelog so that the tag points to the intended commit including the changelog.

### Docker container
The repository itself contains two Dockerfiles, `Dockerfile` and
`Dockerfile.app`. Both are equally usable, where `Dockerfile.app` contains just
the script and `Dockerfile` which are both based on Alpine Linux and in
addition to the script also contains the testing infrastructure.

While either container can be build using the traditional docker syntax, it is
recommended to pull the tagged images from this repositories registry.

## Releases and tagging
To create a release, an annotated tag is to be used. A tag shall have the form
of '${TAG_PREFIX}X.Y[.Z][-rcN]'.
* X required major version of the release, can be any integer value
* Y required minor version of the release, can be any integer value
* Z optional hotfix version of the release only used in release branches
* N optional release candidate of the release, can be any integer value

To create a release branch, tag the master branch with the major and minor
components only.
So for example *v0.10* or *v2019.3*. The CI should then create the needed
branches and tags on a successful build. Without a CI to do this, manual branch
creation is needed. Further more, the initial tag is to be added by the CI as
well, *v0.10.0-rc1* in this example.

Note, that only full tags are considered in the CHANGELOG.md, not any *-rc* or
other postfix to the tag.

### Proper release
If after a certain amount of time, the release candidate is deemed ready for
release, it shall be tagged with its release tag. For example *v0.10.0* to mark
*v0.10.0-rc1* as to be released. In other words a new tag without the *-rc*
component.

#### Hotfixes
Within the main release branch (release/v0.10) hotfix patches can be applied. 
If a release candidate is desired for a certain number of hotfixes, tag the
release branch as such, for example *v0.10.0-rc1*. If there has been a hotfix
release already, then the numbering should take this into account. For example
*v0.10.1-rc0* and so if another release candidate is to follow the tag would be
*v0.10.1-rc1*

 To create a new release with these hotfixes, a new tag is to be created
in the form of *v0.10.1* to release *v0.10.1-rc1*.

#### Annotated tags
Annotated tags are required, as all scripts will ignore light tags. The tag
subject will be used as the release name, and the tag body will be used as
release notes. As such it is strongly recommended to use messaged tags.

### Multi branch releases
When multi-branch releases are done, for example where multiple products or
architectures share a master, but have small differences over its variants,
a postfix can be added. While this adds complexity to the CI, this script
should just work. This comes into play when creating a release branch. Using
an architecture based branching hierarchy, a branch called
*release/v0.10/library* would be created for the 'main' branch, and each
subsequent architecture branch would be then created and updated by the CI.

The main branch 'library' was chosen here, as this is the common name for
docker registries, any other name would work equally, it is the CI that would
use this to distinguish itself.

Having no 'postfix' for the main branch is a possibility also but would make
scripting in the CI slightly more complex.

#### Merging
An important note about merging, a CI should do updates and merges across all
branches based from the *release/vX.Y/library* branch. As such, merges into the
release branches should be avoided, as conflicts cannot be resolved by the CI.

To avoid race conditions, ensure that not two tags are pushed before other
tasks have finished in the CI. This mostly is a problem when many concurrent
tasks are enabled and thus run in parallel on the CI.

The recommended strategy is thus to fork from master by creating the branch tag,
and add fixes that need to be applied to other branches, for example a fix
already on master, the change is to be cherry picked. Fixes from a release
branch back to master should follow the normal
*fix-branch, merge request -> merge (into master)*
principle.

### Manual releasing without a CI
After tagging a release branch, create the release branch matching the tag.
For example when tagging *v0.10* a branch "release/v0.10" is to be created.
Within this branch, the first release candidate is to be added, *v0.10.0-rc1*
in this case.

## Git hooks
As hosted environment do not allow installing pre-receive hooks, we can only
ensure proper tags are pushed. A proper tag always points to a commit updating
the *CHANGELOG.md* file. Included in this repository is a git *pre-push* hook
that checks if the supplied tag follows this rule. Everybody that has the
ability and permission to create any release tag (see above) will need to either
do this completely manually (not recommended) or use the preferred method by
installing the supplied *pre-push* hook from the '.githooks' directory by either
manually copying the file to '.git/hooks' or tell git to use the .githooks
directory instead allowing for version managed and updated hooks
(strongly recommended).

```console
git config --local core.hooksPath .githooks
```

The hook is generic enough that it should be able to be copied into any
repository. It searches based on the environment variable `TAG_PREFIX` and
defaults to `v`.

# Summary
* To tag create a release branch `git_tag_release.sh -a -s v1.0`. The CI creates
*release/v1.0* branch or similar
* To tag release; `git checkout release/v1.0 && git_tag_release.sh -a -s v1.0.0`
* Hotfix-flow -> cherry-pick/am/commit -> tag

For changelog history:
* always put the proper title in the subject line of the
merge message, prefixed with a keep-a-changelog tag (prefix: <subject>) for
the master branch
* all commits are added to the changelog on release branches after the first one
