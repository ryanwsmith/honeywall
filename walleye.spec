Summary:  Walleye Honeynet data analysis 
Name: walleye
Version: 1.1
Release: 31
License: GPL
Group:   Applications/Honeynet
URL:     http://project.honeynet.org/tools/download/walleye-%{version}-%{release}.tar.gz 
Source0: %{name}-%{version}-%{release}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Requires: httpd 
%description
Walleye is a web-based Honeynet data analysis interface.  Hflow is
used to populated the database, Walleye is used to examine this data.
Walleye provides cross data source views of intrusion events that
we attempt to make workflow centric.

%define etcdir	  /etc/
%define walleye   /var/www/html/walleye
%define perldir   /usr/lib/perl5/vendor_perl

%prep
%setup -n  %{name}-%{version}-%{release}

%build

%install
rm -rf $RPM_BUILD_ROOT              
mkdir -p $RPM_BUILD_ROOT%{etcdir}/walleye
mkdir -p $RPM_BUILD_ROOT%{etcdir}/init.d
mkdir -p $RPM_BUILD_ROOT%{walleye}
mkdir -p $RPM_BUILD_ROOT%{walleye}/icons
mkdir -p $RPM_BUILD_ROOT%{walleye}/images
mkdir -p $RPM_BUILD_ROOT%{walleye}/admin/templates/img
mkdir -p $RPM_BUILD_ROOT%{perldir}/Walleye


install -m 0550 -o root -g root httpd.conf        $RPM_BUILD_ROOT%{etcdir}/walleye
install -m 0550 -o root -g root walleye-httpd     $RPM_BUILD_ROOT%{etcdir}/init.d

install -m 0550 -o apache -g apache *.pl              $RPM_BUILD_ROOT%{walleye}
ln $RPM_BUILD_ROOT%{walleye}/walleye.pl $RPM_BUILD_ROOT%{walleye}/index.pl
install -m 0550 -o apache -g apache  admin/*.pl       $RPM_BUILD_ROOT%{walleye}/admin
#install -m 0550 -o apache -g apache  admin/*.pm       $RPM_BUILD_ROOT%{walleye}/admin

install -m 0550 -o apache -g apache  admin/templates/*.*       $RPM_BUILD_ROOT%{walleye}/admin/templates/
install -m 0550 -o apache -g apache  admin/templates/img/*.*       $RPM_BUILD_ROOT%{walleye}/admin/templates/img/

install -m 0444 -o root   -g root modules/Walleye/*.pm $RPM_BUILD_ROOT%{perldir}/Walleye

install -m 0440 -o apache -g apache *.css             $RPM_BUILD_ROOT%{walleye}
install -m 0440 -o apache -g apache *.jpg             $RPM_BUILD_ROOT%{walleye}
install -m 0440 -o apache -g apache *.png             $RPM_BUILD_ROOT%{walleye}
install -m 0440 -o apache -g apache *.gif             $RPM_BUILD_ROOT%{walleye}
install -m 0440 -o apache -g apache *.ico             $RPM_BUILD_ROOT%{walleye}
install -m 0440 -o apache -g apache icons/*.png       $RPM_BUILD_ROOT%{walleye}/icons

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,-,-)
%{etcdir}/walleye/httpd.conf
%{etcdir}/init.d/walleye-httpd

%{perldir}/Walleye/*.pm
%{walleye}/*.pl
%{walleye}/*.css
%{walleye}/*.png
%{walleye}/*.jpg
%{walleye}/*.gif
%{walleye}/*.ico
%{walleye}/icons/*.png
%{walleye}/images
%{walleye}/admin/*.pl
#%{walleye}/admin/*.pm
%{walleye}/admin/templates/*.*
%{walleye}/admin/templates/img/*.*

%post

if [ $1 -eq 1 ]; then
        #--- install
        /usr/bin/openssl genrsa 1024 > /etc/walleye/server.key
	chmod go-rwx /etc/walleye/server.key 
	openssl req -new -key /etc/walleye/server.key -x509 -days 365 -out /etc/walleye/server.crt -batch -set_serial `date +%s`
	chown apache %{walleye}/images
	ln -s /usr/lib/httpd/modules /etc/walleye/modules
	/sbin/chkconfig --add walleye-httpd	
fi


if [ $1 -ge 2 ]; then
        #--- upgrade, dont create new ssl key, and we dont even need to restart httpd 
        #/sbin/service walleye-httpd condrestart
	chown apache %{walleye}/images
fi



