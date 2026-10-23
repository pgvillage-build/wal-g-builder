%global _prefix /usr/local
Summary: Archival and Restoration for PostgreSQL databases
Name: wal-g-pg
Version: %{_version}
Release: 1%{?dist}
License: Apache-2.0
Group: Applications/Databases
Url: %{_url}
BuildArch: %{_arch}
# libsodium, lzo and brotli are linked statically; rpmbuild generates the
# remaining (glibc) dependencies automatically.

%description
Archival and Restoration for databases in the Cloud

%prep

%install
mkdir -p %{buildroot}/%{_bindir}
%{__install} -m 0755 %{_bindir}/wal-g-pg %{buildroot}/%{_bindir}/wal-g-pg

%clean
rm -rf $RPM_BUILD_ROOT

%files
%{_bindir}/wal-g-pg
