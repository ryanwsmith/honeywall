Summary:  Walleye Honeynet data analysis 
Name: walleye
Version: 1.2.5
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
%description
Walleye is a web-based Honeynet data analysis interface.  Hflow is
used to populated the database, Walleye is used to examine this data.
Walleye provides cross data source views of intrusion events that
we attempt to make workflow centric.

%define etcdir	  /etc/
%define walleye_dir   /var/www/html/walleye/

%prep
%setup -n  %{name}-%{version}

%build

%install    
rm -rf %{buildroot}          

#create dirs
%{__install} -d -m0755 %{buildroot}%{walleye_dir}/
%{__install} -d -m0755 %{buildroot}%{walleye_dir}/icons/
%{__install} -d -m0755 %{buildroot}%{walleye_dir}/images/
%{__install} -d -m0755 %{buildroot}%{walleye_dir}/admin/templates/img/
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/httpd/conf.d/
%{__install} -d -m0755 %{buildroot}%{_sysconfdir}/walleye/

#install web files..
%{__install} -m0555  *.pl         %{buildroot}%{walleye_dir}
%{__install} -m0550  admin/*.pl   %{buildroot}%{walleye_dir}/admin/
%{__install} -m0550  admin/templates/*.*       %{buildroot}%{walleye_dir}/admin/templates/
%{__install} -m0550  admin/templates/img/*.*   %{buildroot}%{walleye_dir}/admin/templates/img/
%{__install} -m0440  *.css             %{buildroot}%{walleye_dir}
%{__install} -m0440  *.jpg             %{buildroot}%{walleye_dir}
%{__install} -m0440  *.png             %{buildroot}%{walleye_dir}
%{__install} -m0440  *.gif             %{buildroot}%{walleye_dir}
install -m 0440 -o apache -g apache icons/*.png       %{buildroot}%{walleye_dir}/icons

#install conf file
%{__install} -m644 walleye.conf %{buildroot}%{_sysconfdir}/httpd/conf.d/

#install docs
%{__install} -m644 walleye.schema %{buildroot}%{_sysconfdir}/walleye/


%clean
rm -rf %{buildroot}

%files
%defattr(-,apache,apache,-)

%{walleye_dir}/*.pl
%{walleye_dir}/*.css
%{walleye_dir}/*.png
%{walleye_dir}/*.jpg
%{walleye_dir}/*.gif
%{_sysconfdir}/walleye/*
%{_sysconfdir}/httpd/conf.d/walleye.conf
%{walleye_dir}/icons/*.png
%{walleye_dir}/images
%{walleye_dir}/admin/*.pl
%{walleye_dir}/admin/templates/*.*
%{walleye_dir}/admin/templates/img/*.*


%post

if [ $1 -eq 1 ]; then
        #--- install
echo "Do not forget to install the hflowd schema and populate the snort signatures "
echo "To install the schema: "
echo "  >mysql -u DB_ROOT_USER -p < /etc/walleye/walleye.schema"	
fi


if [ $1 -ge 2 ]; then
        #--- upgrade, dont create new ssl key, and we dont even need to restart httpd 
	#Need to ensure the walleye user can alter the sensor table of hflow db
	echo "Make sure the walleye user can alter the hflow.sensor table."
        echo "To verify: "
	echo "  mysql> use mysql;"
        echo "  mysql> select * from mysql.tables_priv where Db = 'hflow' and User = 'walleye' and Table_name = 'sensor';"
	echo "To add:"
	echo "  mysql> GRANT ALL PRIVILEGES on hflow.sensor to 'walleye'@'localhost' identified by 'honey';"
	echo "  mysql> FLUSH PRIVILEGES;"
fi

