#!/usr/bin/env bash
#
# Package the wal-g-pg binary as a .deb (Debian counterpart of build-rpm.sh /
# specs/wal-g-pg.spec).
#
# Usage: ./scripts/build-deb.sh
#   WALGVERSION  wal-g version (default: taken from `wal-g-pg -v`)
#   WALGURL      homepage (default: https://github.com/mannemsolutions/wal-g/branches)
#   WALGBINARY   binary to package (default: wal-g-pg from $PATH)
#   ARCH         Debian architecture (default: detected from the build host)
#   OUT_DIR      directory to write the .deb to (default: ./debs)
#
# Uses dpkg-deb when available, otherwise assembles the .deb with ar + tar
# (so it also works on macOS without extra tooling).

set -euo pipefail

PKG_NAME="wal-g-pg"
WALGBINARY="${WALGBINARY:-$(command -v wal-g-pg || true)}"
if [ ! -x "${WALGBINARY}" ]; then
  echo "wal-g-pg binary not found; set WALGBINARY" >&2
  exit 1
fi

WALGVERSION=${WALGVERSION:-$("${WALGBINARY}" -v | awk '{print $3}' | grep -oE 'v?[a-zA-Z0-9.]*' || true)}
WALGVERSION=${WALGVERSION:-v0.0.0}
WALGURL=${WALGURL:-https://github.com/mannemsolutions/wal-g/branches}
# Same as RPMVERSION in build-rpm.sh, but Debian versions must start with a
# digit, so strip the tag's leading "v" (and fall back for branch names).
VERSION="${WALGVERSION%-*}"
VERSION="${VERSION#v}"
[[ "${VERSION}" =~ ^[0-9] ]] || VERSION="0.0.0~${VERSION}"
# Like %{?dist} in the rpm spec: tag the revision with the distro release
# (e.g. 1~debian12, 1~ubuntu24.04) so builds for different distros don't clash.
REVISION="1"
if [ -r /etc/os-release ]; then
  DIST="$(. /etc/os-release && echo "${ID:-}${VERSION_ID:-}")"
  [ -n "${DIST}" ] && REVISION="${REVISION}~${DIST}"
fi

detect_arch() {
  if command -v dpkg >/dev/null 2>&1; then
    dpkg --print-architecture
    return
  fi
  case "$(uname -m)" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *) echo "unsupported architecture: $(uname -m)" >&2; return 1 ;;
  esac
}
ARCH="${ARCH:-$(detect_arch)}"

OUT_DIR="${OUT_DIR:-$(pwd)/debs}"
DEB_FILE="${OUT_DIR}/${PKG_NAME}_${VERSION}-${REVISION}_${ARCH}.deb"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

PKG_ROOT="${WORK_DIR}/pkg"
mkdir -p "${PKG_ROOT}/DEBIAN"

# --- package tree ------------------------------------------------------------
# The rpm spec uses _prefix /usr/local, so install to the same location.
mkdir -p "${PKG_ROOT}/usr/local/bin"
install -m 0755 "${WALGBINARY}" "${PKG_ROOT}/usr/local/bin/wal-g-pg"

INSTALLED_SIZE="$(du -sk "${PKG_ROOT}" | cut -f1)"

# No Depends: libsodium, lzo and brotli are linked statically and libc6 is
# essential.

cat > "${PKG_ROOT}/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}-${REVISION}
Section: database
Priority: optional
Architecture: ${ARCH}
Maintainer: pgvillage-tools <noreply@github.com>
Installed-Size: ${INSTALLED_SIZE}
Homepage: ${WALGURL}
Description: Archival and Restoration for PostgreSQL databases
 Archival and Restoration for databases in the Cloud
EOF

# --- build .deb --------------------------------------------------------------
mkdir -p "${OUT_DIR}"
rm -f "${DEB_FILE}"

if command -v dpkg-deb >/dev/null 2>&1; then
  dpkg-deb --root-owner-group --build "${PKG_ROOT}" "${DEB_FILE}"
else
  # Manual assembly: a .deb is an ar archive of debian-binary,
  # control.tar.gz and data.tar.gz (in that order).
  if tar --version 2>/dev/null | grep -q bsdtar; then
    OWNER_OPTS=(--uid 0 --gid 0 --uname root --gname root)
  else
    OWNER_OPTS=(--owner=0 --group=0 --numeric-owner)
  fi
  BUILD_DIR="${WORK_DIR}/deb"
  mkdir -p "${BUILD_DIR}"
  echo "2.0" > "${BUILD_DIR}/debian-binary"
  COPYFILE_DISABLE=1 tar "${OWNER_OPTS[@]}" -czf "${BUILD_DIR}/control.tar.gz" \
    -C "${PKG_ROOT}/DEBIAN" .
  COPYFILE_DISABLE=1 tar "${OWNER_OPTS[@]}" -czf "${BUILD_DIR}/data.tar.gz" \
    -C "${PKG_ROOT}" --exclude ./DEBIAN .
  (cd "${BUILD_DIR}" && ar rc "${DEB_FILE}" debian-binary control.tar.gz data.tar.gz)
fi

echo "Built ${DEB_FILE}"
