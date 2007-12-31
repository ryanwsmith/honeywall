# $Id: $

%define rules_ver 2007-03-08

Name: snortrules-snapshot
Version: 2.6
Release: hw.1
License: MOU
Source: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
Packager: Honeynet Project
Group: Applications/Internet
Summary: VRT Certified Rules for Snort® %{rules_ver}
URL: http://www.snort.org/pub-bin/downloads.cgi
Requires: snort
Requires(post): /bin/ln
Requires(post): /bin/chown

###############################################################################
%define snort_conf_dir %{_sysconfdir}/snort
%define rules_dir %{snort_conf_dir}/rules
%define rules_doc_dir %{_docdir}/%{name}
###############################################################################
# Don't 'strip' etc.  Not necessary, takes forever with this man files
%define __os_install_post /usr/lib/rpm/brp-compress
###############################################################################

%description
       Snort® VRT Certified Rules realeased on: %{rules_ver}
“VRT Certified Rules” are defined as those Snort® rules that have been
created, developed, tested and officially approved by the Sourcefire 
Vulnerability Research Team (VRT). These rules are designated with 
SIDs of 3,465-1,000,000, except as otherwise noted in the license file.

  Please review the VRT License: /etc/snort/rules/VRT-License.txt

These rules are being installed as a starting point for the Honeynet 
Project "roo" Honeywall.  Register for free VRT rules updates at:

          https://www.snort.org/pub-bin/register.cgi

                   Snort and the Snort logo 
          are trademarks or registered trademarks of 
                       Sourcefire, Inc.

%prep
rm -rf %{buildroot}
%setup -q -c

%install
%{__install} -d -m 0755 %{buildroot}%{rules_dir}
%{__install} -d -m 0755 %{buildroot}%{rules_doc_dir}
find doc -type f -exec %{__install} -p -m 0644 {} %{buildroot}%{rules_doc_dir} \;
# Don't wont this one...
%{__rm} -f rules/snort.conf
find rules -type f -exec %{__install} -p -m 0644 {} %{buildroot}%{rules_dir} \;

%post
# Set up links to the misc conf files for oinkmaster
(cd /etc/snort; for CONF in sid-msg.map classification.config generators reference.config threshold.conf unicode.map; do %{__ln_s} rules/${CONF} .; done)

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root)
%{rules_doc_dir}/*
%{rules_dir}/*

%changelog
* Sun Feb 25 2007 Honeynet Project <project@honeynet.org>
- Added requires for ln in post
- Updated source and rules_ver to 2007-02-20
- Includes rule for DCE/RPC vuln

* Sun Feb 11 2007 Honeynet Project <project@honeynet.org>
- Total re-write with Makefile

* Mon Nov 06 2006 Honeynet Project <project@honeynet.org>
- Removing /etc/snort/rules/snort.conf
- Set rules_ver to reflect 2006-10-18 Rule update
- Removed references to inline stuff
- Making links to misc confs to play nice with oinkmaster

* Thu Aug 17 2006 Honeynet Project <project@honeynet.org>
- Set rules_ver to reflect 2006-08-11 Rule update

* Thu Jul 13 2006 Honeynet Project <project@honeynet.org>
- Added chown to rules/docs so installed files will be owned by root
- Changed perms on tar/md5 to 0600

* Wed Jul 12 2006 Honeynet Project <project@honeynet.org>
- Removed chmmod on inline rules dir since they arent there yet (duh)
- Changed to using rules date for version
- Added number after hw to indicate build release

* Mon Jul 10 2006 Honeynet Project <project@honeynet.org>
- No longer copying *.config to /etc/snort_inline
- Fixed perm issue on /etc/snort, /etc/snort_inline dirs

* Tue Jun 20 2006 Honeynet Project <project@honeynet.org>
- Uncommented mkdir for doc_dir, forgot we still need that

* Mon Jun 19 2006 Honeynet Project <project@honeynet.org>
- Just learned its best to use *.config etc from rules instead of source
- Changes made accordingly
- Also making RPM static filename to ease auto building / incorprating
- Added %{rules_ver} def at top and in description

* Mon Jun 12 2006 Honeynet Project <project@honeynet.org>
- Removed all files except rules and VRT License
- Removed %post RULE_PATH fix (not inclusing snort.conf)

* Fri Jun 02 2006 Honeynet Project <project@honeynet.org>
- Initial build


