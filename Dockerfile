FROM golang:alpine AS builder

COPY SigningKeys SigningKeys

ARG RESTIC_TAG

ENV GOPATH="${GOPATH:-/go}" PASS_VERSION="1.7.3"

RUN apk --update upgrade && \
    apk add bash ca-certificates git gnupg tree util-linux && \
    apk add --virtual .build-depends \
      curl jq make && \
    mkdir -v -m 0700 -p /root/.gnupg && \
    gpg2 --no-options --verbose --keyid-format 0xlong --keyserver-options auto-key-retrieve=true \
        --import SigningKeys && rm -f SigningKeys && \
    mkdir -v -m 0755 -p "${GOPATH}/src/github.com/restic" && \
    git clone --no-checkout --dissociate --reference-if-able /restic.git \
        'https://github.com/restic/restic.git' \
        "${GOPATH}/src/github.com/restic/restic" && \
    [ -n "$RESTIC_TAG" ] || { curl -sSL 'https://api.github.com/repos/restic/restic/releases/latest' | jq -r '[.["tag_name"],.["prerelease"]]|select(.[1] == false)|"RESTIC_TAG="+.[0]' > /tmp/latest-restic-tag.sh && . /tmp/latest-restic-tag.sh; } && \
    (cd "${GOPATH}/src/github.com/restic/restic" && git tag -v "$RESTIC_TAG" && git checkout "$RESTIC_TAG") && \
    rm -rf /root/.gnupg && \
    curl -Lo /root/pass.tar.xz "https://git.zx2c4.com/password-store/snapshot/password-store-${PASS_VERSION}.tar.xz" && \
    mkdir -v /root/pass && tar -C /root/pass -xpvvf /root/pass.tar.xz && rm -f /root/pass.tar.xz &&\
    (cd "/root/pass/password-store-${PASS_VERSION}" && make PREFIX='/usr/local' install) && \
    apk del --purge .build-depends && rm -rf /var/cache/apk/*

WORKDIR "${GOPATH:-/go}/src/github.com/restic/restic"

RUN go run build.go && sha256sum restic && ./restic version

FROM alpine
LABEL maintainer="https://keybase.io/tcely"

ENV GOPATH="${GOPATH:-/go}"

COPY --from=builder "${GOPATH:-/go}"/src/github.com/restic/restic/restic /usr/bin/restic
COPY --from=builder /usr/local/ /usr/local/

RUN apk --update upgrade && \
    apk add bash ca-certificates fuse git gnupg openssh-client tree util-linux && \
    rm -rf /var/cache/apk/*

ENTRYPOINT ["/usr/bin/restic"]
CMD ["--help"]
