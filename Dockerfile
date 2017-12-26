FROM golang:alpine AS builder
MAINTAINER tcely <tcely@users.noreply.github.com>

ADD SigningKeys .

ENV GOPATH="${GOPATH:-/go}"

ARG RESTIC_TAG v0.8.0

RUN apk --update upgrade && \
    apk add ca-certificates && \
    apk add --virtual .build-depends \
      git gnupg && \
    mkdir -v -m 0700 -p /root/.gnupg && \
    gpg2 --no-options --verbose --keyid-format 0xlong --import SigningKeys && rm -f SigningKeys && \
    mkdir -v -m 0755 -p "${GOPATH}/src/github.com/restic" && \
    git clone --no-checkout --dissociate --reference-if-able /restic.git \
        'https://github.com/restic/restic.git' \
        "${GOPATH}/src/github.com/restic/restic" && \
    (cd "${GOPATH}/src/github.com/restic/restic" && git tag -v "$RESTIC_TAG" && git checkout "$RESTIC_TAG") && \
    rm -rf /root/.gnupg && \
    apk del .build-depends && rm -rf /var/cache/apk/*

WORKDIR "${GOPATH:-/go}/src/github.com/restic/restic"

RUN go run build.go && sha256sum restic && ./restic version

FROM alpine
MAINTAINER tcely <tcely@users.noreply.github.com>

ENV GOPATH="${GOPATH:-/go}"

COPY --from=builder "${GOPATH:-/go}"/src/github.com/restic/restic/restic /usr/bin/restic

RUN apk --update upgrade && \
    apk add ca-certificates fuse openssh-client && \
    rm -rf /var/cache/apk/*

ENTRYPOINT ["/usr/bin/restic"]
