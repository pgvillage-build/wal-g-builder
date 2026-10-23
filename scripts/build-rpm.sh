#!/bin/bash
set -ex
WALGVERSION=${WALGVERSION:-$(wal-g-pg -v | awk '{print $3}' | grep -oE 'v?[a-zA-Z0-9.]*')}
WALGVERSION=${WALGVERSION:-v0.0.0}
RPMVERSION=${RPMVERSION:-${WALGVERSION%-*}}
WALGURL=${WALGURL:-https://github.com/mannemsolutions/wal-g/branches}
# openSUSE does not set %{dist}, so tag the release like OBS does (e.g. .lp160)
# to tell builds for different versions apart.
DIST=$(rpm --eval '%{?dist}')
if [ -z "$DIST" ] && grep -qi '^ID=.*opensuse' /etc/os-release; then
  DIST=".lp$(. /etc/os-release && echo "${VERSION_ID//./}")"
fi
# openSUSE defaults %_topdir to /usr/src/packages
echo "
%_version $RPMVERSION
%_url $WALGURL
%_topdir $HOME/rpmbuild
${DIST:+%dist $DIST}
" >~/.rpmmacros
rpmbuild -ba ./specs/wal-g-pg.spec
mkdir -p ./rpms/
cp ~/rpmbuild/RPMS/*/*.rpm ./rpms/
