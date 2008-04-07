Summary: web based pcap retrieval API 
Name: pcap_api 
Version: 1.1.0
Release: 1
License: GPL Indiana University 2007 
Group: Applications/Honeynet
URL: http://project.honeynet.org/tools/download/%{name}-%{ver}.%{rel}.tar.gz 
Source0: %{name}-%{version}-%{release}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Requires: walleye >= 1.2 wireshark >= 0.99
%description
Web Based API for retrieval of PCAP files.  pgrep can return
a dynamically generated pcap file that contains ONLY the packets
requested, such as all packets related to a specific network
connection.

%define pcapdir /var/log/pcap 
%define wwwdir  /var/www/html/walleye

%prep
%setup -n %{name}-%{version}-%{release}

%build
%configure
make

%install
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/sbin/
mkdir -p $RPM_BUILD_ROOT%{pcapdir}
mkdir -p $RPM_BUILD_ROOT%{wwwdir}
 %__mkdir -p -m 0755 $RPM_BUILD_ROOT%{_mandir}/man8


install -m 0555 -o root -g root pcap_api         $RPM_BUILD_ROOT/usr/sbin/
install -m 0550 -o apache -g apache pcap_api.pl      $RPM_BUILD_ROOT%{wwwdir}
 %__install -p -m 0644 pcap_api.8 $RPM_BUILD_ROOT%{_mandir}/man8
 %__gzip $RPM_BUILD_ROOT%{_mandir}/man8/pcap_api.8


%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/usr/sbin/pcap_api
%attr(-,apache,apache)%{wwwdir}/pcap_api.pl
%dir %{pcapdir}
%{_mandir}/man8/pcap_api.8.gz


%doc


%changelog
* Wed Jan  5 2005 root <root@localhost.localdomain> - 
- Initial build.

