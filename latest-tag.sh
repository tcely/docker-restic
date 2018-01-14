#!/bin/bash

. <(curl -sSL 'https://api.github.com/repos/restic/restic/releases/latest' | jq -r '[.["tag_name"],.["prerelease"]]|select(.[1] == false)|"RESTIC_TAG="+.[0]')

[ -n "${RESTIC_TAG}" ] || exit 0

git describe "$RESTIC_TAG" &>/dev/null && exit 0

keybase chat send --nonblock tcely "restic/restic: [${RESTIC_TAG}] detected a new release"

{ printf 'ARG RESTIC_TAG=%s\n\n' "$RESTIC_TAG"; cat Dockerfile; } > Dockerfile.tmp

mv Dockerfile.tmp Dockerfile && \
  git add Dockerfile && \
  git commit --no-gpg-sign -m "Set tag to: ${RESTIC_TAG}"

git checkout HEAD^ -- Dockerfile
