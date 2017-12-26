FROM golang:alpine AS builder
MAINTAINER tcely <tcely@users.noreply.github.com>

ADD SigningKeys .

ENV GOPATH="${GOPATH:-/go}" download_url='https://github.com/restic/restic/releases/download'

# v0.8.0 is currently the latest
ARG RESTIC_TAG

RUN apk --update upgrade && \
    apk add ca-certificates && \
    apk add --virtual .build-depends \
      curl git gnupg && \
    curl -LRSs -O "${download_url}/${RESTIC_TAG}/SHA256SUMS.asc" && \
    curl -LRSs -O "${download_url}/${RESTIC_TAG}/SHA256SUMS" && \
    awk > shellvars -v "url=${download_url}" -v "tag=${RESTIC_TAG}" \
        '/\.tar\.gz$$/ { \
            hash=$1; \
            $1=""; \
            sub(/^ +/, ""); \
            printf "restic_hash='\''%s'\'' restic_src_url='\''%s/%s/%s'\''\n", \
                hash, url, tag, $0; \
        }' SHA256SUMS && \
    . shellvars && rm -f shellvars && \
    curl -LRSs -O "${restic_src_url}" && \
    curl -LRSs -O "${restic_src_url}.asc" && \
    mkdir -v -m 0700 -p /root/.gnupg && \
    gpg2 --no-options --verbose --keyid-format 0xlong --import SigningKeys && rm -f SigningKeys && \
    gpg2 --no-options --verbose --keyid-format 0xlong --verify-files *.asc && \
    grep "^${restic_hash}" SHA256SUMS | sha256sum -c | tee HashedArchive && \
    mkdir -v -m 0755 -p "${GOPATH}/src/github.com/restic" && \
    tar -C "${GOPATH}/src/github.com/restic" -xpf "`sed -e 's/: OK$//' HashedArchive`" && rm -f HashedArchive && \
    git clone --no-checkout --dissociate --reference-if-able /restic.git \
        'https://github.com/restic/restic.git' \
        "${GOPATH}/src/github.com/restic/restic" && \
    (cd "${GOPATH}/src/github.com/restic/restic" && git tag -v "$RESTIC_TAG" && git checkout "$RESTIC_TAG") && \
    rm -rf /root/.gnupg && \
    apk del .build-depends && rm -rf /var/cache/apk/*

WORKDIR "${GOPATH:-/go}/src/github.com/restic"

RUN cd restic && go run build.go && sha256sum restic && ./restic version
RUN set -v && cd restic-* && go run build.go && sha256sum restic && ./restic version

FROM alpine
MAINTAINER tcely <tcely@users.noreply.github.com>

ENV GOPATH="${GOPATH:-/go}"

COPY --from=builder "${GOPATH:-/go}"/src/github.com/restic/restic-*/restic /usr/bin/restic

RUN apk --update upgrade && \
    apk add ca-certificates fuse openssh-client && \
    rm -rf /var/cache/apk/*

ENTRYPOINT ["/usr/bin/restic"]
