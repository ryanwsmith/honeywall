%define ver     1.0
%define rel     0
Summary: Hflow2 configuration
Name: hflow-config-hw
Version: %ver
Release: %rel
License: GPL Honeynet Project 2008
Group: Applications/Internet
Source0: http://project.honeynet.org/tools/download/%{name}-%{version}-%{release}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
URL: http://project.honeynet.org/tools/hflow
Requires: hflow >= 1.99
Requires(post): /sbin/chkconfig
Requires(post): /sbin/service

%description
Hflow2 configuration integrates hflow2 into the honeywall, and handles starting applications that the previous hflow used to handle.

%define etcdir		/etc/hflow
%define hflowdir	/usr
%define hflowsbin	%{hflowdir}/sbin

%prep
%setup -n %{name}-%{ver}-%{rel}
%build
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{etcdir}
mkdir -p $RPM_BUILD_ROOT/etc/init.d
mkdir -p $RPM_BUILD_ROOT/hw/bin
mkdir -p $RPM_BUILD_ROOT%{hflowsbin}

install -m 0440 my.cnf            $RPM_BUILD_ROOT%{etcdir}
install -m 0440 hflow-config-hw.schema   $RPM_BUILD_ROOT%{etcdir}
install -m 0550 createBpfFilter.py $RPM_BUILD_ROOT/hw/bin
install -m 0550 init.d/hw-mysqld       $RPM_BUILD_ROOT/etc/init.d
install -m 0550 init.d/hw-p0f          $RPM_BUILD_ROOT/etc/init.d
install -m 0550 init.d/hw-pcap         $RPM_BUILD_ROOT/etc/init.d
install -m 0550 init.d/hw-snort_inline $RPM_BUILD_ROOT/etc/init.d

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT

%post 
if [ $1 -eq 1 ]; then
	#--- no other instances must be an install not upgrade
	/sbin/chkconfig --add hw-mysqld
	/sbin/chkconfig --add hw-p0f
	/sbin/chkconfig --add hw-pcap
	/sbin/chkconfig --add hw-snort_inline
	/sbin/chkconfig --add hflow
	/sbin/chkconfig snortd off
fi

if [ $1 -eq 2 ]; then
	#--- this was an upgrate, make sure to restart the deamons
	/sbin/service hw-mysqld restart
	/sbin/service hw-p0f    restart
	/sbin/service hw-pcap   restart
	/sbin/service hw-snort_inline  restart
        /sbin/service hflow restart
	/sbin/chkconfig snortd off
fi


%preun
if [ $1 -eq 0 ]; then
	#--- on uninstall if $1 == 0 then we are removing hflowd
	/sbin/chkconfig --del hw-mysqld
	/sbin/chkconfig --del hw-p0f
	/sbin/chkconfig --del hw-pcap
	/sbin/chkconfig --del hw-snort_inline
        /sbin/chkconfig --del hflow
fi

%files
%defattr(-,root,root)
/etc/init.d/hw-mysqld
/etc/init.d/hw-p0f
/etc/init.d/hw-pcap
/etc/init.d/hw-snort_inline
/hw/bin/createBpfFilter.py
%dir %{etcdir}

%config %{etcdir}/my.cnf
%config %{etcdir}/hflow-config-hw.schema
