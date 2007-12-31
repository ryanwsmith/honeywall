# $Id: tcpdstat-uw.spec.ews 2429 2005-10-25 19:35:31Z esammons $
#############################################
#
# Copyright (C) <2005> <The Honeynet Project>
#
# This program is free software; you can redistribute it and/or modify 
# it under the terms of the GNU General Public License as published by 
# the Free Software Foundation; either version 2 of the License, or (at 
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License 
# along with this program; if not, write to the Free Software 
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 
# USA
#
#############################################

Summary:	tcpdump trace file analyzer
Summary(pl):	Analizator pliku ¶ledzenia tcpdump
Name:		tcpdstat-uw
Version:	1.0
Release:	2
License:	GPL
Group:		Applications/Networking
Source0:	http://staff.washington.edu/dittrich/talks/core02/tools/%{name}.tar
# Source0-md5:	64b246fb0a4ee47ae37e83d721b205df
URL:		http://www.csl.sony.co.jp/person/kjc/papers/freenix2000/node14.html
BuildRequires:	libpcap-devel
#BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	i386
Packager: 	Honeynet Project

%description
Tcpdstat a program to extract statistical information from tcpdump
trace files. Tcpdstat reads a tcpdump file using the pcap library and
prints the statistics of a trace. The output includes the number of
packets, the average rate and its standard deviation, the number of
unique source and destination address pairs, and the breakdown of
protocols. Tcpdstat is intended to provide a rough idea of the trace
content. The output can be easily converted to a HTTP format. It also
provides helpful information to find anomaly in a trace.

%description -l pl
Tcpdstat jest programem wy³uskuj±cym statystyki z plików ¶ledzenia
tcpdumpa. Tcpdstat czyta taki plik u¿ywaj±c biblioteki pcap i
wy¶wietla statystyki ¶ledzenia. Wyj¶cie zawiera liczbê pakietów,
¶redni± przep³ywno¶æ i jej odchylenie standardowe, liczbê unikalnych
par adresów ¼róde³ i celów oraz rozk³ad protoko³ów. Tcpdstat ma
zapewniaæ ogólny ogl±d prze¶ledzonych po³±czeñ. Wyj¶cie mo¿e byæ ³atwo
przekonwertowane na format HTTP. Podaje równie¿ informacje przydatne w
odnajdywaniu anomalii.

%prep
%setup -q -n %{name}

%build
# Fix to build on gcc 4x 
%{__sed} -i 's/static int packet_length/int packet_length/' net_read.c

%{__make} \
	CC="%{__cc}" \
	CFLAGS="" \
	INCLUDES="-I."

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT%{_bindir}

install tcpdstat $RPM_BUILD_ROOT%{_bindir}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644,root,root,755)
%doc README.uw
%attr(755,root,root) %{_bindir}/tcpdstat


%changelog
* Fri Mar 23 2007 <esammons@hush.com>
- Added Buildrequires for libpcap-devel

* Wed Mar 21 2007 <esammons@hush.com>
- Updated release for new build

* Fri Mar 16 2007 <esammons@hush.com>
- Stripped improperly formated changelog items

* Wed Mar 14 2007 <esammons@hush.com>
- Updated to build in new roo-1.2 build env
- Added sed line in buid so this will build with gcc 4x


