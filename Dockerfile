# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Copyright 2019 (C) Olliver Schinagl <oliver@schinagl.nl>

FROM registry.hub.docker.com/library/alpine:edge

LABEL Maintainer="Olliver Schinagl <oliver@schinagl.nl>"

# We want the latest stable version
# hadolint ignore=DL3018
RUN \
    sed -i 's|\(^http.*\)community|&\n\1testing|' "/etc/apk/repositories" && \
    apk add --no-cache \
        git \
        shunit2 \
    && \
    rm -rf "/var/cache/apk/"*

COPY "./dockerfiles/buildenv_check.sh" "/test/buildenv_check.sh"
