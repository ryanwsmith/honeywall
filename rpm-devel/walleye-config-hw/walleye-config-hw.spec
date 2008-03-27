%define ver     1.0
%define rel     1
Summary: Walleye configuration
Name: walleye-config-hw
Version: %ver
Release: %rel
License: GPL Honeynet Project 2008
Group: Applications/Internet
Source0: http://project.honeynet.org/tools/download/%{name}-%{version}-%{release}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
URL: http://project.honeynet.org/tools/hflow
Requires: walleye >= 1.2
Requires(post): /sbin/chkconfig
Requires(post): /sbin/service

%description
Integrates the walleye for hflow2 into the honeywall.

%define etcdir		/etc/walleye

%prep
%setup -n %{name}-%{ver}-%{rel}
%build
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{etcdir}
mkdir -p $RPM_BUILD_ROOT/etc/init.d

install -m 0440 walleye-httpd.conf     $RPM_BUILD_ROOT%{etcdir}
install -m 0550 init.d/walleye-httpd   $RPM_BUILD_ROOT/etc/init.d

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT

%post 
if [ $1 -eq 1 ]; then
	#--- no other instances must be an install not upgrade
	/sbin/chkconfig --add walleye-httpd
	/usr/bin/dot -c
	/bin/chmod 644 /usr/lib/graphviz/config
	/bin/chmod 755 /var/www/html/walleye/images
fi

if [ $1 -eq 2 ]; then
	#--- this was an upgrate, make sure to restart the deamons
	/sbin/service walleye-httpd restart
fi


%preun
if [ $1 -eq 0 ]; then
	#--- on uninstall if $1 == 0 then we are removing hflowd
	/sbin/chkconfig --del walleye-httpd
fi

%files
%defattr(-,root,root)
/etc/init.d/walleye-httpd
%config %{etcdir}/walleye-httpd.conf
