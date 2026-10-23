ARG BASEIMAGE=rockylinux:10
FROM ${BASEIMAGE} AS build-stage
ARG GITREV
ARG WALGVERSION
# el needs epel (libsodium) and crb (lzo-devel), fedora and opensuse have it all
RUN . /etc/os-release && \
    case "${ID}" in \
      opensuse*) \
        zypper -n install git cmake rpm-build lzo-devel libsodium-devel tar gzip curl gcc make pkg-config && \
        zypper clean -a ;; \
      fedora) \
        dnf install -y git cmake rpm-build lzo-devel libsodium-devel tar gcc make pkg-config && \
        dnf clean all ;; \
      *) \
        dnf install -y dnf-plugins-core epel-release && crb enable && \
        dnf install -y git cmake rpm-build lzo-devel libsodium-devel tar gcc make pkg-config && \
        dnf clean all ;; \
    esac

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
COPY --from=build-stage /usr/local/bin/wal-g-pg /usr/local/bin/
# wal-g-pg links libsodium, lzo and brotli statically, so only rpm-build is needed
RUN if grep -qi '^ID=.*opensuse' /etc/os-release; then \
      zypper -n install rpm-build && zypper clean -a; \
    else \
      dnf install -y rpm-build && dnf clean all; \
    fi
CMD /usr/local/bin/wal-g-pg
