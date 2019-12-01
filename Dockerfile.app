# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright 2019 (C) Olliver Schinagl <oliver@schinagl.nl>

# We want the latest version from the repo for now
# hadolint ignore=DL3007
FROM registry.hub.docker.com/gitscm/git:latest

LABEL Maintainer="Olliver Schinagl <oliver@schinagl.nl>"

COPY "./dockerfiles/docker-entrypoint.sh" "/init"
COPY "./bin/git_tag_release.sh" "/usr/local/bin/git_tag_release.sh"

ENTRYPOINT [ "/init" ]
