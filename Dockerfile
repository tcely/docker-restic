ARG RESTIC_TAG=v0.10.0

FROM golang:alpine3.13 AS builder

COPY SigningKeys SigningKeys
COPY SigningKeys.pass SigningKeys.pass
#ADD https://www.zx2c4.com/keys/AB9942E6D4A4CFC3412620A749FC7012A5DE03AE.asc SigningKeys.pass

ARG RESTIC_TAG
ARG PASS_TAG="1.7.4"

ENV GOPATH="${GOPATH:-/go}"

RUN apk --update upgrade && \
    apk add bash ca-certificates git gnupg tree util-linux && \
    apk add --virtual .build-depends \
      curl jq make && \
    mkdir -v -m 0700 -p /root/.gnupg && \
    gpg2 --no-options --verbose --keyid-format 0xlong --keyserver-options auto-key-retrieve=true \
        --import SigningKeys && \
    gpg2 --no-options --verbose --keyid-format 0xlong --keyserver-options auto-key-retrieve=true \
        --import SigningKeys.pass && \
    mkdir -v -m 0755 -p "${GOPATH}/src/github.com/restic" && \
    git clone --no-checkout --dissociate --reference-if-able /restic.git \
        'https://github.com/restic/restic.git' \
        "${GOPATH}/src/github.com/restic/restic" && \
    [ -n "$RESTIC_TAG" ] || { curl -sSL 'https://api.github.com/repos/restic/restic/releases/latest' | jq -r '[.["tag_name"],.["prerelease"]]|select(.[1] == false)|"RESTIC_TAG="+.[0]' > /tmp/latest-restic-tag.sh && . /tmp/latest-restic-tag.sh; } && \
    (cd "${GOPATH}/src/github.com/restic/restic" && git tag -v "$RESTIC_TAG" && git checkout "$RESTIC_TAG") && \
    git clone --no-checkout --dissociate --reference-if-able /password-store.git \
        'https://git.zx2c4.com/password-store' \
        '/root/password-store' && \
    (cd '/root/password-store' && git tag -v "$PASS_TAG" && git checkout "$PASS_TAG" && make PREFIX='/usr/local' install) && \
    rm -rf /root/.gnupg && \
    apk del --purge .build-depends && rm -rf /var/cache/apk/*

WORKDIR "${GOPATH:-/go}/src/github.com/restic/restic"

RUN go run build.go && sha256sum restic && ./restic version

FROM alpine:3.13
LABEL maintainer="https://keybase.io/tcely"

ENV GOPATH="${GOPATH:-/go}"

COPY --from=builder "${GOPATH:-/go}"/src/github.com/restic/restic/restic /usr/bin/restic
COPY --from=builder /usr/local/ /usr/local/

RUN apk --update upgrade && \
    apk add bash ca-certificates fuse git gnupg openssh-client tree util-linux && \
    rm -rf /var/cache/apk/*

ENTRYPOINT ["/usr/bin/restic"]
CMD ["--help"]
