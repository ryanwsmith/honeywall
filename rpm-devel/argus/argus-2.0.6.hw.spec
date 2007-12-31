Name: argus
Version: 2.0.6.fixes.1
#EWS Release: 10%{?dist}
Release: 10%{?dist}.hw1
Summary: Network transaction audit tool
License: GPL
Group: Applications/Internet
Url: http://qosient.com/argus
Source0: ftp://ftp.qosient.com/dev/argus-2.0/%{name}-%{version}.tar.gz
Source1: ftp://ftp.qosient.com/dev/argus-2.0/%{name}-clients-%{version}.tar.gz
Source2: argus.init
Source3: README.fedora
Patch0: argus-2.0.6.fixes.1-makefile.patch
Patch1: argus-2.0.6.fixes.1-build.patch
Patch2: argus-clients-2.0.6.fixes.1-makefile.patch
Patch3: argus-clients-2.0.6.fixes.1-build.patch
Patch4: argus-clients-2.0.6.fixes.1-print.patch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires(post): /sbin/chkconfig
Requires(preun): /sbin/chkconfig
#Requires: libpcap
BuildRequires: libpcap cyrus-sasl-devel tcp_wrappers flex bison ncurses-devel

%package clients
Summary: Client tools for argus network audit
Group: Applications/Internet

%description
Argus (Audit Record Generation and Utilization System) is an IP network
transaction audit tool. The data generated by argus can be used for a
wide range of tasks such as network operations, security and performance
management.

%description clients
Clients to the argus probe which process and display information.

%prep
%setup -a0
%setup -a1
%patch0 -p1
%patch1 -p1
pushd %{name}-clients-%{version}
%patch2 -p1
%patch3 -p1
%patch4 -p1
popd
%{__install} -p -m 0644 %{SOURCE3} .

%build
#EWS %configure --with-sasl=yes
%configure --with-sasl=no
%{__make} %{?_smp_mflags}
pushd %{name}-clients-%{version}
#EWS %configure --with-sasl=yes
%configure --with-sasl=no
%{__make} %{?_smp_mflags}
popd

%install
%{__rm} -rf %{buildroot}
%{__make} DESTDIR=%{buildroot} install
pushd %{name}-clients-%{version}
%{__make} DESTDIR=%{buildroot} install
# avoid unwanted dependencies when using these as docs (clients package):
find doc contrib support ragraph -type f -exec chmod a-x '{}' \;
popd
%{__rm} -rf %{buildroot}/%{_libdir}
%{__rm} -rf %{buildroot}/%{_bindir}/ragraph
%{__install} -d -m 0755 %{buildroot}/%{_localstatedir}/lib/argus/archive
%{__install} -D -m 0644 support/Config/argus.conf %{buildroot}/%{_sysconfdir}/argus.conf
%{__install} -D -m 0755 %{SOURCE2} %{buildroot}/%{_initrddir}/argus
# fix up argus.conf to a good default
%{__sed} -i 's|var/log/argus|var/lib/argus|' %{buildroot}/%{_sysconfdir}/argus.conf
%{__sed} -i 's|#ARGUS_BIND_IP|ARGUS_BIND_IP|' %{buildroot}/%{_sysconfdir}/argus.conf
%{__sed} -i 's|#ARGUS_ACCESS_PORT|ARGUS_ACCESS_PORT|' %{buildroot}/%{_sysconfdir}/argus.conf
# avoid unwanted dependencies when using these as docs (main package):
find support -type f -exec chmod a-x '{}' \;

%clean
%{__rm} -rf %{buildroot}

%post
# only post-install
if [ $1 -le 1 ]; then
	/sbin/chkconfig --add argus
fi

%preun
# only pre-erase
if [ $1 -eq 0 ]; then
	/sbin/service argus stop >/dev/null 2>&1
	/sbin/chkconfig --del argus
fi

%postun
# only postun-upgrade
if [ $1 -ge 1 ]; then
	/sbin/service argus condrestart >/dev/null 2>&1
fi

%files
%defattr(-,root,root)
%doc support doc/CHANGES doc/FAQ doc/HOW-TO doc/html bin/argusbug
%doc COPYING CREDITS INSTALL README VERSION
%config(noreplace) %{_sysconfdir}/argus.conf
%{_initrddir}/argus
%{_sbindir}/argus*
%{_mandir}/man5/argus*
%{_mandir}/man8/argus*
%dir %{_localstatedir}/lib/argus
%dir %{_localstatedir}/lib/argus/archive

%files clients
%doc %{name}-clients-%{version}/ChangeLog %{name}-clients-%{version}/COPYING
%doc %{name}-clients-%{version}/CREDITS %{name}-clients-%{version}/INSTALL
%doc %{name}-clients-%{version}/README %{name}-clients-%{version}/VERSION
%doc %{name}-clients-%{version}/doc/CHANGES %{name}-clients-%{version}/doc/FAQ
%doc %{name}-clients-%{version}/doc/HOW-TO %{name}-clients-%{version}/doc/html
%doc %{name}-clients-%{version}/support
%doc %{name}-clients-%{version}/ragraph/ragraph.pl
# .pm checked for dependencies regardless of permissions
#%doc %{name}-clients-%{version}/contrib
%doc README.fedora
%{_bindir}/ra*
%{_mandir}/man1/ra*
%{_mandir}/man5/ra*

%changelog
* Thu Jun 15 2006 Earl Sammons <esammons@hush.com> 2.0.6.fixes.1-10.hw1
- Dropping SASL support

* Fri Apr 21 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-10
- bumped release to workaround botched CVS tag attempt

* Fri Apr 21 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-9
- daemon patches now eliminate unused common files: argus_parse.c, argus_util.c, and argus_auth.c

* Mon Mar 20 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-8
- added ncurses-devel build requirement

* Wed Mar 15 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-7
- fixed argus makefile patch

* Fri Mar 10 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-6
- argus.conf now enables listening for connections on localhost
- added README.fedora to clients subpackage explaining contrib situation and ra printing patch

* Wed Mar 08 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-5
- added patch from Peter Van Epp <vanepp@sfu.ca> to fix ra printing bugs

* Mon Mar 06 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-4
- removing execute flag from all documentation
- capture file location changed /var/argus -> /var/lib/argus
- init script set to default-disabled

* Sun Mar 05 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-3
- backed out of __perl_requires redefine for .pm files - trouble w. rpmbuild

* Fri Feb 24 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-2
- empty perl_req/prov avoids .pm's in %doc from being dep-checked at all
- misc spec file fixes

* Fri Feb 24 2006 Gabriel Somlo <somlo at cmu.edu> 2.0.6.fixes.1-1
- initial build for fedora extras
