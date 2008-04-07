Summary:  Walleye Honeywall Config 
Name: hwall-http-conf
Version: 1.2.1
Release: 2
License: GPL
Group:   Applications/Honeynet
URL:     http://project.honeynet.org/tools/download/walleye-%{version}-%{release}.tar.gz 
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
buildarch: noarch
Requires: httpd 
Requires: perl
Requires: perl-DateManip
Requires: perl-HTML-Parser
Requires: perl-Walleye-Util
Requires: graphviz
Requires: mod_ssl
Requires: walleye
%description
Walleye is a web-based Honeynet data analysis interface.  Hflow is
used to populated the database, Walleye is used to examine this data.
Walleye provides cross data source views of intrusion events that
we attempt to make workflow centric.

%define http_conf_dir %{_sysconfdir}/httpd/conf
#%define perldir   /usr/lib/perl5/vendor_perl

%prep
%setup -n  %{name}-%{version}

%build

%install    
rm -rf %{buildroot}          
#mkdir -p $RPM_BUILD_ROOT%{etcdir}/walleye
#mkdir -p $RPM_BUILD_ROOT%{etcdir}/init.d
#mkdir -p $RPM_BUILD_ROOT%{walleye}
#mkdir -p $RPM_BUILD_ROOT%{walleye}/icons
#mkdir -p $RPM_BUILD_ROOT%{walleye}/images
#mkdir -p $RPM_BUILD_ROOT%{walleye}/admin/templates/img

#create dirs
%{__install} -d -m0755 %{buildroot}%{http_conf_dir}
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/walleye/

#install apache conf
%{__install}  -b -m0755 httpd.conf %{buildroot}%{http_conf_dir}


%clean
#rm -rf $RPM_BUILD_ROOT
rm -rf %{buildroot}

%files
%defattr(-,root,root,0644)

%{http_conf_dir}/httpd.conf


%post

if [ $1 -eq 1 ]; then
        #--- install
        /usr/bin/openssl genrsa 1024 > /etc/walleye/server.key
	chmod go-rwx /etc/walleye/server.key 
	openssl req -new -key /etc/walleye/server.key -x509 -days 365 -out /etc/walleye/server.crt -batch -set_serial `date +%s`
#	chown apache %{walleye}/images
#	ln -s /usr/lib/httpd/modules /etc/walleye/modules
	/sbin/chkconfig --add httpd
fi


if [ $1 -ge 2 ]; then
        #--- upgrade, dont create new ssl key, and we dont even need to restart httpd 
        #/sbin/service walleye-httpd condrestart
#	chown apache %{walleye}/images
echo "Nothing to do (for now)"
fi



