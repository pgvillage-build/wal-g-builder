ARG BASEIMAGE=debian:12
FROM ${BASEIMAGE} AS build-stage
ARG GITREV
ARG WALGVERSION
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl git cmake build-essential pkg-config liblzo2-dev libsodium-dev && \
    rm -rf /var/lib/apt/lists/*

ENV GO_VERSION=1.27.1
ENV PATH=$PATH:/usr/local/go/bin
ENV GOPATH=/go
ENV PATH=$PATH:$GOPATH/bin
ARG TARGETARCH

RUN curl -OL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf "go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" && \
    rm "go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" && \
    mkdir -p "$GOPATH/src" "$GOPATH/bin"

WORKDIR /go/src/app
COPY wal-g .
RUN USE_BROTLI=yes USE_LIBSODIUM=yes USE_LZO=yes make deps && \
    go build -v -tags "brotli libsodium liblzo" -ldflags "-s -w -X github.com/wal-g/wal-g/cmd/pg.buildDate=`date -u +%Y.%m.%d_%H:%M:%S` -X github.com/wal-g/wal-g/cmd/pg.gitRevision=$GITREV -X github.com/wal-g/wal-g/cmd/pg.walgVersion=$WALGVERSION" -o /usr/local/bin/wal-g-pg ./main/pg

FROM ${BASEIMAGE}
# wal-g-pg links libsodium, lzo and brotli statically, so no runtime packages
COPY --from=build-stage /usr/local/bin/wal-g-pg /usr/local/bin/
CMD /usr/local/bin/wal-g-pg
