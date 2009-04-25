# $Id: $

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
Name: roo-base
# Version follows CentOS version so yum $releasever works
Version: 5
Release: 36.hw
License: GPL
Source: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch: noarch
Packager: Honeynet Project
Group: Applications/Internet
Summary: Honeywall functionality in a box
URL: http://www.honeynet.org/tools/cdrom/roo/
Vendor: Honeynet Project
#Obsoletes: fedora-logos
Provides: system-logos
# This is so yum "distroverpkg works
Provides: /etc/redhat-release
Requires: coreutils sysklogd sudo mktemp sed grep initscripts grub crontabs
Requires: snort snortrules-snapshot kernel selinux-policy oinkmaster
Requires(post): /sbin/chkconfig
Requires(post): /usr/sbin/useradd
Requires(post): /bin/chmod
Requires(preun): /sbin/chkconfig
Requires(preun): /sbin/service

%description
The roo package contains all the files that implement basic
honeywall functionality, all in a nice little package.

%prep
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

#######################################################################
# setup macro
# -a num  : Only unpack source number after changing to the directory
# -b num  : Only unpack source number before changing to the directory
# -c      : Create directory before unpacking.
# -D      : Do not delete the directory before unpacking
# -n name : Name the directory as name
# -q      : Run quiety with minimum output
# -T      : Disable the automatic unpacking of the archives.
#######################################################################
%setup -q -n src

#%build
#########################################################
# Common Red Hat RPM macros (rpm --showrc for more info)
# {_sourcedir} : /usr/src/redhat/SOURCES
# {_builddir}  : /usr/src/redhat/BUILD
# {_tmppath}   : /var/tmp
# {_libdir}    : /usr/lib
# {_bindir}    : /usr/bin
# {_datadir}   : /usr/share
# {_mandir}    : /usr/share/man
# {_docdir}    : /usr/share/doc
#########################################################

%install
%{__install} -d -m 755 %{buildroot}/hw/bin
%{__install} -d -m 755 %{buildroot}/hw/conf
%{__install} -d -m 755 %{buildroot}/hw/docs
%{__install} -d -m 755 %{buildroot}/hw/lib
%{__install} -d -m 755 %{buildroot}/hw/etc
# Use sticky bit set to prevent unauthorized deletions.
%{__install} -d -m 1777 %{buildroot}/hw/tmp
%{__install} -d -m 755 %{buildroot}/hw/var/log
%{__install} -d -m 755 %{buildroot}/hw/var/run
%{__install} -d -m 755 %{buildroot}/hw/var/spool
%{__install} -d -m 755 %{buildroot}/hw/etc/tripwire
%{__install} -d -m 755 %{buildroot}/hw/etc/logrotate.d
%{__install} -d -m 755 %{buildroot}/hw/sbin

%{__install} -D -m 0640 etc/whitelist.txt %{buildroot}/etc/whitelist.txt
%{__install} -D -m 0640 etc/blacklist.txt %{buildroot}/etc/blacklist.txt
%{__install} -D -m 0640 etc/fencelist.txt %{buildroot}/etc/fencelist.txt
%{__install} -D -m 0700 etc/monitrc %{buildroot}/etc/monitrc
%{__install} -D -m 0644 etc/redhat-release %{buildroot}/etc/redhat-release
%{__install} -D -m 0644 etc/argus_summary.conf %{buildroot}/etc/argus_summary.conf
%{__install} -D -m 0644 etc/swatchrc %{buildroot}/etc/swatchrc
%{__install} -D -m 0644 etc/dialogrc %{buildroot}/etc/dialogrc
%{__install} -D -m 0644 etc/honeywall.conf %{buildroot}/etc/honeywall.conf
%{__install} -D -m 0644 etc/honeywall.conf %{buildroot}/etc/honeywall.conf.orig
%{__install} -D -m 0750 etc/rc.d/init.d/bridge.sh %{buildroot}/etc/rc.d/init.d/bridge.sh
%{__install} -D -m 0750 etc/rc.d/init.d/hwdaemons %{buildroot}/etc/rc.d/init.d/hwdaemons
%{__install} -D -m 0755 etc/rc.d/init.d/hwfuncs.sub %{buildroot}/etc/rc.d/init.d/hwfuncs.sub
%{__install} -D -m 0750 etc/rc.d/init.d/hwnetwork %{buildroot}/etc/rc.d/init.d/hwnetwork
%{__install} -D -m 0750 etc/rc.d/init.d/monit.sh %{buildroot}/etc/rc.d/init.d/monit.sh
%{__install} -D -m 750 etc/rc.d/init.d/rc.firewall %{buildroot}/etc/rc.d/init.d/rc.firewall
%{__install} -D -m 0750 etc/rc.d/init.d/swatch.sh %{buildroot}/etc/rc.d/init.d/swatch.sh
%{__install} -D -m 0750 etc/rc.d/init.d/hwdont_run %{buildroot}/etc/rc.d/init.d/hwdont_run
%{__install} -D -m 0644 etc/yum.repos.d/honeynet.repo %{buildroot}/etc/yum.repos.d/honeynet.repo
%{__install} -D -m 0644 etc/yum.repos.d/honeynet-test.repo %{buildroot}/etc/yum.repos.d/honeynet-test.repo
%{__install} -D -m 0644 etc/yum.repos.d/os-base.repo %{buildroot}/etc/yum.repos.d/os-base.repo
%{__install} -D -m 0644 etc/yum.repos.d/os-updates.repo %{buildroot}/etc/yum.repos.d/os-updates.repo
%{__install} -D -m 0644 etc/yum.repos.d/os-extras.repo %{buildroot}/etc/yum.repos.d/os-extras.repo
%{__install} -D -m 0644 etc/yum.repos.d/rpmforge.repo %{buildroot}/etc/yum.repos.d/rpmforge.repo
%{__install} -D -m 0644 etc/yum.repos.d/epel.repo %{buildroot}/etc/yum.repos.d/epel.repo
%{__install} -D -m 0644 etc/yum.repos.d/media.repo %{buildroot}/etc/yum.repos.d/media.repo
%{__install} -D -m 0644 boot/grub/splash.xpm.gz %{buildroot}/boot/grub/splash.xpm.gz
%{__install} -D -m 0644 boot/grub/honeywall.xpm.gz %{buildroot}/boot/grub/honeywall.xpm.gz
%{__install} -D -m 0750 dlg/ShowDocs.sh %{buildroot}/dlg/ShowDocs.sh
%{__install} -D -m 0750 dlg/dowerundialog.sh %{buildroot}/dlg/dowerundialog.sh
%{__install} -D -m 0750 dlg/checkfiles %{buildroot}/dlg/checkfiles
%{__install} -D -m 0750 dlg/Status.sh %{buildroot}/dlg/Status.sh
%{__install} -D -m 0750 dlg/dialogmenu.sh %{buildroot}/dlg/dialogmenu.sh
%{__install} -D -m 0750 dlg/SetupHoneywall.sh %{buildroot}/dlg/SetupHoneywall.sh
%{__install} -D -m 0644 dlg/README %{buildroot}/dlg/README
%{__install} -D -m 0750 dlg/HoneyConfig.sh %{buildroot}/dlg/HoneyConfig.sh
%{__install} -D -m 0644 dlg/docs.tgz %{buildroot}/dlg/docs.tgz
%{__install} -D -m 0750 dlg/Administration-menu.sh %{buildroot}/dlg/Administration-menu.sh
%{__install} -D -m 0750 dlg/HoneyAdmin.sh %{buildroot}/dlg/HoneyAdmin.sh
%{__install} -D -m 0750 dlg/honeywall_init.sh %{buildroot}/dlg/honeywall_init.sh
%{__install} -D -m 0750 dlg/admin/DirectoryInitialization.sh %{buildroot}/dlg/admin/DirectoryInitialization.sh
%{__install} -D -m 0750 dlg/admin/AddUser.sh %{buildroot}/dlg/admin/AddUser.sh
%{__install} -D -m 0750 dlg/admin/SSHConfig.sh %{buildroot}/dlg/admin/SSHConfig.sh
%{__install} -D -m 0750 dlg/admin/MakeConfigs.sh %{buildroot}/dlg/admin/MakeConfigs.sh
%{__install} -D -m 0750 dlg/admin/DirectoryCleanup.sh %{buildroot}/dlg/admin/DirectoryCleanup.sh
%{__install} -D -m 0750 dlg/admin/Password.sh %{buildroot}/dlg/admin/Password.sh
%{__install} -D -m 0750 dlg/config/hw_build_ssh_config.sh %{buildroot}/dlg/config/hw_build_ssh_config.sh
%{__install} -D -m 0750 dlg/config/ModeConfig.sh %{buildroot}/dlg/config/ModeConfig.sh
%{__install} -D -m 0750 dlg/config/FenceList.sh %{buildroot}/dlg/config/FenceList.sh
%{__install} -D -m 0750 dlg/config/purgeDB.pl %{buildroot}/dlg/config/purgeDB.pl
%{__install} -D -m 0750 dlg/config/BlackWhite.sh %{buildroot}/dlg/config/BlackWhite.sh
%{__install} -D -m 0750 dlg/config/ChangeEmail.pl %{buildroot}/dlg/config/ChangeEmail.pl
%{__install} -D -m 0750 dlg/config/createWhiteRules.pl %{buildroot}/dlg/config/createWhiteRules.pl
%{__install} -D -m 0750 dlg/config/Summary.sh %{buildroot}/dlg/config/Summary.sh
%{__install} -D -m 0750 dlg/config/RoachMotel.sh %{buildroot}/dlg/config/RoachMotel.sh
%{__install} -D -m 0750 dlg/config/purgePcap.pl %{buildroot}/dlg/config/purgePcap.pl
%{__install} -D -m 0644 dlg/config/README %{buildroot}/dlg/config/README
%{__install} -D -m 0750 dlg/config/Email.pl %{buildroot}/dlg/config/Email.pl
%{__install} -D -m 0750 dlg/config/DNSConfig.sh %{buildroot}/dlg/config/DNSConfig.sh
%{__install} -D -m 0750 dlg/config/SebekConfig.sh %{buildroot}/dlg/config/SebekConfig.sh
%{__install} -D -m 0750 dlg/config/ConnectionLimit.sh %{buildroot}/dlg/config/ConnectionLimit.sh
%{__install} -D -m 0750 dlg/config/dns2resolv.sh %{buildroot}/dlg/config/dns2resolv.sh
%{__install} -D -m 0750 dlg/config/createBPFFilter.pl %{buildroot}/dlg/config/createBPFFilter.pl
%{__install} -D -m 0750 dlg/config/DataManage.sh %{buildroot}/dlg/config/DataManage.sh
%{__install} -D -m 0750 dlg/config/SnortinlineConfig.sh %{buildroot}/dlg/config/SnortinlineConfig.sh
%{__install} -D -m 0750 dlg/config/snortrules_cron.sh %{buildroot}/dlg/config/snortrules_cron.sh
%{__install} -D -m 0750 dlg/config/snortrules_config.sh %{buildroot}/dlg/config/snortrules_config.sh
%{__install} -D -m 0750 dlg/config/ManagementOpts.sh %{buildroot}/dlg/config/ManagementOpts.sh
%{__install} -D -m 0750 dlg/config/createBlackRules.pl %{buildroot}/dlg/config/createBlackRules.pl
%{__install} -D -m 0750 dlg/config/Upload.sh %{buildroot}/dlg/config/Upload.sh
%{__install} -D -m 0750 dlg/status/argus.sh %{buildroot}/dlg/status/argus.sh
%{__install} -D -m 0750 dlg/status/tcpdstat.sh %{buildroot}/dlg/status/tcpdstat.sh
%{__install} -D -m 0750 dlg/status/conntrack.sh %{buildroot}/dlg/status/conntrack.sh
%{__install} -D -m 0640 hw/Makefile.hwctl %{buildroot}/hw/Makefile.hwctl
%{__install} -D -m 0640 hw/etc/logrotate.d/rpm %{buildroot}/hw/etc/logrotate.d/rpm
%{__install} -D -m 0640 hw/etc/logrotate.d/syslog %{buildroot}/hw/etc/logrotate.d/syslog
%{__install} -D -m 0640 hw/etc/logrotate.d/yum %{buildroot}/hw/etc/logrotate.d/yum
%{__install} -D -m 0640 etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5 %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5
%{__install} -D -m 0640 etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL
%{__install} -D -m 0640 etc/pki/rpm-gpg/RPM-GPG-KEY-beta %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY-beta
%{__install} -D -m 0640 etc/pki/rpm-gpg/RPM-GPG-KEY.honeynet.txt %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY.honeynet.txt
%{__install} -D -m 0640 etc/pki/rpm-gpg/RPM-GPG-KEY.dag.txt %{buildroot}/etc/pki/rpm-gpg/RPM-GPG-KEY.dag.txt
%{__install} -D -m 0640 hw/etc/tripwire/twpol.txt %{buildroot}/hw/etc/tripwire/twpol.txt
%{__install} -D -m 0644 hw/docs/CREDITS %{buildroot}/hw/docs/CREDITS
%{__install} -D -m 0644 hw/docs/LICENSE %{buildroot}/hw/docs/LICENSE
%{__install} -D -m 0644 hw/docs/README %{buildroot}/hw/docs/README
%{__install} -D -m 0644 hw/docs/README.snortrules %{buildroot}/hw/docs/README.snortrules
%{__install} -D -m 0644 hw/docs/README.internals %{buildroot}/hw/docs/README.internals
%{__install} -D -m 0644 hw/docs/README.ssh_hwconf_import %{buildroot}/hw/docs/README.ssh_hwconf_import
%{__install} -D -m 0750 hw/sbin/hwruleupdate %{buildroot}/hw/sbin/hwruleupdate
%{__install} -D -m 0700 usr/sbin/menu %{buildroot}/usr/sbin/menu
%{__install} -D -m 0750 usr/sbin/bootcustom.sh %{buildroot}/usr/sbin/bootcustom.sh
%{__install} -D -m 0750 usr/local/bin/privmsg.pl %{buildroot}/usr/local/bin/privmsg.pl
%{__install} -D -m 0750 usr/local/bin/showvars %{buildroot}/usr/local/bin/showvars
%{__install} -D -m 0750 usr/local/bin/connect_count %{buildroot}/usr/local/bin/connect_count
%{__install} -D -m 0750 usr/local/bin/ircdump.py %{buildroot}/usr/local/bin/ircdump.py
%{__install} -D -m 0750 usr/local/bin/summary.sh %{buildroot}/usr/local/bin/summary.sh
%{__install} -D -m 0750 usr/local/bin/rpm-key-import %{buildroot}/usr/local/bin/rpm-key-import
%{__install} -D -m 0750 usr/local/bin/lockdown-hw.sh %{buildroot}/usr/local/bin/lockdown-hw.sh
%{__install} -D -m 0750 usr/local/bin/traffic_summary.py %{buildroot}/usr/local/bin/traffic_summary.py
%{__install} -D -m 0750 usr/local/bin/runtw.sh %{buildroot}/usr/local/bin/runtw.sh
%{__install} -D -m 0750 usr/local/bin/ipgrep %{buildroot}/usr/local/bin/ipgrep
%{__install} -D -m 0750 usr/local/bin/loadvars %{buildroot}/usr/local/bin/loadvars
%{__install} -D -m 0750 usr/local/bin/hwrepoconf %{buildroot}/usr/local/bin/hwrepoconf
%{__install} -D -m 0750 usr/local/bin/hwctl %{buildroot}/usr/local/bin/hwctl
%{__install} -D -m 0750 usr/local/bin/hwvarcheck %{buildroot}/usr/local/bin/hwvarcheck
%{__install} -D -m 0750 usr/local/bin/dumpvars %{buildroot}/usr/local/bin/dumpvars
%{__install} -D -m 0750 usr/local/bin/hwreset_tally.sh %{buildroot}/usr/local/bin/hwreset_tally.sh
%{__install} -D -m 0750 usr/local/bin/getstats %{buildroot}/usr/local/bin/getstats
%{__install} -D -m 0750 usr/local/bin/get-cached-updates.sh %{buildroot}/usr/local/bin/get-cached-updates.sh

##################################################
# Parameter 	%pre 	%post    %preun  %postun #
# 1st install  	  1 	  1 	   N/C 	   N/C   #
# Upgrade 	  2 	  2 	    1 	    1    #
# Removal 	 N/C 	 N/C 	    0 	    0    #
##################################################

# If upgrade, stop HW services (will make this smarter later)
#if [ $1 == 2 ]; then
#	/etc/init.d/hwdaemons stop || :
#	/etc/init.d/rc.firewall stop || :
#fi

################################################################################
%post
################################################################################
if [ $1 -eq 1 ]; then
# DO IF INSTALL
#######################################
# Create user 'roo' password "honey"
   /usr/sbin/useradd -p '$1$mdOgmbxC$ZtXFdACTRLlkom8fTUyaA0' roo

# Enable HW services
   for SERVICE_ADD in rc.firewall hwnetwork bridge.sh hwdont_run swatch.sh; do
	chkconfig --add ${SERVICE_ADD}
   done

# Disable stuff we dont need (by default)
   for SERVICE_OFF in mcstrans ip6tables restorecond; do
	chkconfig ${SERVICE_OFF} off
   done

# Disable IPV6
   sed -i 's,NETWORKING_IPV6=yes,NETWORKING_IPV6=no,' /etc/sysconfig/network
   if [ "$(grep -c 'alias net-pf-10 off' /etc/modprobe.conf)" -ne 1 ]; then
	echo "alias net-pf-10 off" >> /etc/modprobe.conf
   fi
   if [ "$(grep -c 'alias ipv6 off' /etc/modprobe.conf)" -ne 1 ]; then
	echo "alias ipv6 off" >> /etc/modprobe.conf
   fi

# Set up the system crontab
cat <<EOF>> /etc/crontab
5 0 * * * root /etc/init.d/hw-snort_inline restart
1 * * * * root /etc/init.d/hw-pcap restart
0 1 * * * root /usr/local/bin/summary.sh
*/10 * * * * root /usr/local/bin/hwreset_tally.sh
EOF

#######################################
# Fix the initial (after install) boot splash
   GRUBC="/boot/grub/grub.conf"
# Determin root device
   rootdev=$(grep -v "#" ${GRUBC} | grep "root.*(" | sed "s/^.*root.*(\(.*\))/\1/" | sort | uniq)
   if [ $(echo ${rootdev} | wc -l) -eq 1 ]; then
# Only one root device, this is good; Check for "splashimage" line
	if [ $(grep -v "#" ${GRUBC} | grep -c "splashimage=(${rootdev})\/boot\/grub\/splash\.xpm\.gz") -ne 1 ]; then
		sed -i "s/\(default.*$\)/splashimage=(${rootdev})\/boot\/grub\/splash\.xpm\.gz\n\1/" ${GRUBC}
	fi
   fi
# check for "hiddenmenu"
   if [ $(grep -v "#" ${GRUBC} | grep -c "hiddenmenu") -lt 1 ]; then
	sed -i "s/\(default.*$\)/hiddenmenu\n\1/" ${GRUBC}
   fi
#######################################
# Create IPS rules
   if [ -x /hw/sbin/hwruleupdate ]; then
	/hw/sbin/hwruleupdate --snortconfig || :
   fi
#######################################
# Disable SELinux :(
   sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config

#######################################
# fix logrotate to look at /hw/etc/logrotate.d for confs
# This should last becaus logrotate has: "%config(noreplace) /etc/logrotate.conf"
   if [ -f /etc/logrotate.conf ]; then
	sed -i 's,include /etc/logrotate.d,include /hw/etc/logrotate.d,' /etc/logrotate.conf
   fi
# END DO IF INSTALL
fi
################################################################################
# DO ON INSTALL or UPGRADE

#######################################
# Fix /etc/sysconfig/sylsog if necessary
syslog_restart="no"
sys_conf="/etc/sysconfig/syslog"
if [ -f "${sys_conf}" ]; then
# Is it ok?
        if [ $(sed /#.*/d ${sys_conf} | grep -c "KLOGD_OPTIONS=\"-x -c 4\"") -lt 1 ] ||
           [ $(sed /#.*/d ${sys_conf} | grep -c "SYSLOGD_OPTIONS=\"-m 0\"") -lt 1 ]; then
		now=$(date +"%Y%m%d-%M%S")
	        echo "Backing up ${sys_conf} to ${sys_conf}.${now}"
	        cp ${sys_conf} ${sys_conf}.${now}
# Put everything back except potential wrong setting(s)
	        sed 's/^[ \t]*//' ${sys_conf}.${now} | egrep -v "^KLOGD_OPTIONS|^SYSLOGD_OPTIONS" > ${sys_conf}
# Hand jam back in what we want
	        echo "KLOGD_OPTIONS=\"-x -c 4\"" >> ${sys_conf}
		echo "SYSLOGD_OPTIONS=\"-m 0\"" >> ${sys_conf}
		syslog_restart="yes"
	fi
else
# We shouldnt be here (Requires: sysklogd) but just in case...
	echo "SYSLOGD_OPTIONS=\"-m 0\"" > ${sys_conf}
	echo "KLOGD_OPTIONS=\"-x -c 4\"" >> ${sys_conf}
	/bin/chmod 0600 ${sys_conf}
	syslog_restart="yes"
fi

#######################################
# Fix /etc/sysconfig/sylog (if necessary)
syslog_conf="/etc/syslog.conf"
if [ -f "${syslog_conf}" ]; then
# Dont look at anything after "#" look for "kern.debug  /var/log/iptables" on a line
# Also look for "local0.*  /hw/var/log/honeywall" on another line
	if [ $(sed /#.*/d ${syslog_conf} | grep "kern\.=debug" | grep -c "\/var\/log\/iptables") -lt 1 ] ||
	   [ $(sed /#.*/d ${syslog_conf} | grep "local0\.\*" | grep -c "\/hw\/var\/log\/honeywall") -lt 1 ]; then
# Strip leading whitespace, backup file to be edited
		now=$(date +"%Y-%m-%d-%M-%S")
	        echo "Backing up ${syslog_conf} to ${syslog_conf}.${now}"
       		cp ${syslog_conf} ${syslog_conf}.${now}
		/bin/chmod 0600 ${syslog_conf}.${now}
# Put everything back except wrong settings
	        sed 's/^[ \t]*//' ${syslog_conf}.${now} | egrep -v "^kern\.=debug|^\*\.emerg|^local0\.\*" > ${syslog_conf}
# Hand jam back in what we want
	        echo "kern.=debug                      /var/log/iptables" >> ${syslog_conf}
#echo "#*.emerg                        *" >> ${syslog_conf}
	        echo "local0.*                         /hw/var/log/honeywall" >> ${syslog_conf}
		/bin/chmod 0600 ${syslog_conf}
		syslog_restart="yes"
	fi
else
# We shouldnt be here (Requires: sysklogd) but if we are...
	echo "kern.=debug                      /var/log/iptables" > ${syslog_conf}
	echo "local0.*                         /hw/var/log/honeywall" >> ${syslog_conf}
	/bin/chmod 0600 ${syslog_conf}
	syslog_restart="yes"
	
fi
###########################################
# Restart syslog if we messed with it in either of the two fixes above
#[ "${syslog_restart}" == "yes" ] && [ -x /etc/init.d/syslog ] && . /etc/init.d/functions && /etc/init.d/syslog restart
if [ $1 -eq 2 ];then
	[ "${syslog_restart}" == "yes" -a -x /etc/init.d/syslog ] && /etc/init.d/syslog restart || :
fi

###########################################
# Fix /etc/sudoers
# Remove ALL ROO stuff if its there
sed -i '/ROO__/d' /etc/sudoers

# Put the current ROO stuff back in
echo "User_Alias ROO__ADMIN = apache" >> /etc/sudoers
echo "Cmnd_Alias ROO__COMMANDS = /proc/net/ip_conntrack, /etc/rc.d/init.d/hwfuncs.sub, /etc/rc.d/init.d/sshd, /etc/init.d/flush_firewall.sh, /etc/init.d/bridge.sh, /etc/init.d/rc.firewall, /etc/init.d/hw-pcap, /etc/init.d/hw-snort_inline, /etc/init.d/hflow, /etc/init.d/swatch.sh, /dlg/config/createWhiteRules.pl, /dlg/config/createBlackRules.pl, /dlg/config/createBPFFilter.pl, /dlg/config/dns2resolv.sh, /dlg/config/hw_build_ssh_config.sh, /usr/bin/tcpdstat, /usr/bin/monit, /usr/sbin/argus, /sbin/shutdown, /sbin/ifconfig, /sbin/iptables, /bin/netstat, /bin/chown, /bin/chmod, /bin/ps, /bin/mv, /bin/cp, /bin/rm, /bin/touch, /bin/cat, /bin/hostname, /etc/rc.d/init.d/hwdaemons, /usr/local/bin/hwctl, /dlg/config/purgePcap.pl, /dlg/config/purgeDB.pl, /usr/bin/du, /bin/ls, /bin/df, /bin/mount, /tmp/unpack-iso.sh, /bin/tar, /hw/sbin/hwruleupdate, /dlg/config/ChangeSSHPort.sh, /bin/loadkeys" >> /etc/sudoers
echo "ROO__ADMIN ALL = NOPASSWD: ROO__COMMANDS" >> /etc/sudoers

# Be sure not to requiretty (So Walleye stuff works)
sed -i 's/^Defaults[ \t]*requiretty/#Defaults requiretty/' /etc/sudoers

###########################################
# Make Lance happy by adding roo-base verion to /etc/issue
if [ -f /etc/issue ]; then
	sed -i /^roo-base.*$/d /etc/issue
fi
echo "roo-base-%{version}-%{release}" >> /etc/issue

###########################################
# If upgrade... 
if [ $1 -eq 2 ]; then
# Set a default val for any potentially newly added vars
	/usr/local/bin/hwvarcheck || :
# Restart HW servivices
	/etc/init.d/hwdaemons restart || :
fi

################################################################################
%preun
################################################################################
if [ $1 -eq 0 ]; then
# DO ON REMOVAL (Cleanup)
###########################################
# Stop and remove HW services
   for SERVICE in rc.firewall hwnetwork bridge.sh hwdont_run swatch.sh; do
        service ${SERVICE} stop &> /dev/null || :
        chkconfig --del ${SERVICE}
   done
###########################################
# Remove the roo user
   userdel roo &> /dev/null || :

fi
################################################################################
%postun
################################################################################

################################################################################
%clean
################################################################################
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

################################################################################
%files
################################################################################
%defattr(-,root,root,-)
%config(noreplace) /etc/whitelist.txt
%config(noreplace) /etc/blacklist.txt
%config(noreplace) /etc/fencelist.txt
%config(noreplace) /etc/monitrc
/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-5
/etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL
/etc/pki/rpm-gpg/RPM-GPG-KEY-beta
/etc/pki/rpm-gpg/RPM-GPG-KEY.honeynet.txt
/etc/pki/rpm-gpg/RPM-GPG-KEY.dag.txt
/etc/redhat-release
/etc/argus_summary.conf
/etc/swatchrc
/etc/dialogrc
%config(noreplace) /etc/honeywall.conf
/etc/honeywall.conf.orig
/etc/rc.d/init.d/bridge.sh
/etc/rc.d/init.d/hwdaemons
/etc/rc.d/init.d/hwfuncs.sub
/etc/rc.d/init.d/hwnetwork
/etc/rc.d/init.d/monit.sh
/etc/rc.d/init.d/rc.firewall
/etc/rc.d/init.d/swatch.sh
/etc/rc.d/init.d/hwdont_run
%config /etc/yum.repos.d/honeynet.repo
%config /etc/yum.repos.d/honeynet-test.repo
%config /etc/yum.repos.d/os-base.repo
%config /etc/yum.repos.d/os-updates.repo
%config /etc/yum.repos.d/os-extras.repo
%config /etc/yum.repos.d/epel.repo
%config /etc/yum.repos.d/rpmforge.repo
%config /etc/yum.repos.d/media.repo

/boot/grub/splash.xpm.gz
/boot/grub/honeywall.xpm.gz 

/dlg/ShowDocs.sh
/dlg/dowerundialog.sh
/dlg/checkfiles
/dlg/Status.sh
/dlg/dialogmenu.sh
/dlg/SetupHoneywall.sh
/dlg/README
/dlg/HoneyConfig.sh
/dlg/docs.tgz
/dlg/Administration-menu.sh
/dlg/HoneyAdmin.sh
/dlg/honeywall_init.sh
/dlg/admin/DirectoryInitialization.sh
/dlg/admin/AddUser.sh
/dlg/admin/SSHConfig.sh
/dlg/admin/MakeConfigs.sh
/dlg/admin/DirectoryCleanup.sh
/dlg/admin/Password.sh
/dlg/config/hw_build_ssh_config.sh
/dlg/config/ModeConfig.sh
/dlg/config/FenceList.sh
/dlg/config/purgeDB.pl
/dlg/config/BlackWhite.sh
/dlg/config/ChangeEmail.pl
/dlg/config/createWhiteRules.pl
/dlg/config/Summary.sh
/dlg/config/RoachMotel.sh
/dlg/config/purgePcap.pl
/dlg/config/README
/dlg/config/Email.pl
/dlg/config/DNSConfig.sh
/dlg/config/SebekConfig.sh
/dlg/config/ConnectionLimit.sh
/dlg/config/dns2resolv.sh
/dlg/config/createBPFFilter.pl
/dlg/config/DataManage.sh
/dlg/config/SnortinlineConfig.sh
/dlg/config/snortrules_cron.sh
/dlg/config/snortrules_config.sh
/dlg/config/ManagementOpts.sh
/dlg/config/createBlackRules.pl
/dlg/config/Upload.sh
/dlg/status/argus.sh
/dlg/status/tcpdstat.sh
/dlg/status/conntrack.sh

/hw/Makefile.hwctl
%config /hw/etc/logrotate.d/rpm
%config /hw/etc/logrotate.d/syslog
%config /hw/etc/logrotate.d/yum
%config /hw/etc/tripwire/twpol.txt
/hw/docs/CREDITS
/hw/docs/LICENSE
/hw/docs/README
/hw/docs/README.snortrules
/hw/docs/README.internals
/hw/docs/README.ssh_hwconf_import
/hw/sbin/hwruleupdate

/usr/sbin/menu
/usr/sbin/bootcustom.sh

/usr/local/bin/privmsg.pl
/usr/local/bin/showvars
/usr/local/bin/connect_count
/usr/local/bin/ircdump.p*
/usr/local/bin/summary.sh
/usr/local/bin/rpm-key-import
/usr/local/bin/lockdown-hw.sh
/usr/local/bin/traffic_summary.p*
/usr/local/bin/runtw.sh
/usr/local/bin/ipgrep
/usr/local/bin/loadvars
/usr/local/bin/hwrepoconf
/usr/local/bin/hwctl
/usr/local/bin/hwvarcheck
/usr/local/bin/dumpvars
/usr/local/bin/hwreset_tally.sh
/usr/local/bin/getstats
/usr/local/bin/get-cached-updates.sh

%dir /hw/bin
%dir /hw/conf
%dir /hw/docs
%dir /hw/lib
%dir /hw/etc
%dir /hw/tmp
%dir /hw/var/log
%dir /hw/var/run
%dir /hw/var/spool
%dir /hw/etc/tripwire
%dir /hw/etc/logrotate.d
%dir /hw/sbin

################################################################################
%changelog
################################################################################
* Thu Dec 27 2007 Earl Sammons <esammons@hush.com>
- Split repos so hwrepoconf works again and added includepkgs and exclude statements

* Thu Nov 29 2007 Earl Sammons <esammons@hush.com>
- RPM-GPG-KEY cleanup and disabled non honeynet repos getting ready for CentOS 5

* Sun Apr 29 2007 Earl Sammons <esammons@hush.com>
- Added hwvarcheck to create default var val files when new vars are added
- Added dialog foo for HwBPF_DISABLE

* Thu Apr 05 2007 Earl Sammons <esammons@hush.com>
- Added commenting out of requiretty in sudoers to fix walleye admin stuff

* Mon Mar 26 2007 Earl Sammons <esammons@hush.com>
- Fixed sudoers mods - user roo should have been user apache
- Hard wired yum repo confs to basearch=i386 and exluded tcpdstat-uw
- Removed unused honeynet-tools repo

* Fri Mar 23 2007 Earl Sammons <esammons@hush.com>
- Disable IPV6
- hwdaemons restart instead of hw_startHoneywall in conifg to defaults (reliability)
 
* Wed Mar 21 2007 Earl Sammons <esammons@hush.com> 
- Disabling mcstrans ip6tables restorecond

* Mon Mar 19 2007 Scott Buchan <sbuchan@hush.com> 
- Upping release for new build
- Fixed typo in HoneyConfig.sh

* Sun Mar 18 2007 Earl Sammons <esammons@hush.com> 
- Sudoers fix is now updatable and wont just whack existing sudoers

* Mon Mar 05 2007 Earl Sammons <esammons@hush.com> 
- Changed version to 6 to fix yum resolving of releasever so update/install
  from upstream repos will work

* Sun Feb 25 2007 Earl Sammons <esammons@hush.com> 
- Added fedora repo config files
- Upped ver

* Sun Feb 11 2007 Earl Sammons <esammons@hush.com>
- Almost a re-write of the SPEC and the build process
- Also updated repo files for new repo locations

* Wed Nov 29 2006 Earl Sammons <esammons@hush.com>
- Added README.internals and README.ssh_hwconf_import
  to files section
- Removed base and updates repos from files section

* Mon Nov 06 2006 Earl Sammons <esammons@hush.com>
- Fixed and re-enabled Black White lists
- Added black_white list deps on snort-plain to hwctl

* Fri Oct 20 2006 Earl Sammons <esammons@hush.com>
- Removed HwRULE* temp hack touch foo

* Mon Oct 16 2006 Earl Sammons <esammons@hush.com>
- Fixed SSHD config process so firewall is auto updated
- Removed UpdateFWSSHPort.sh (No longer needed)
- Re-ordered hwdaemons start stop same as init
- Created backup hwdaemons_old just to be sure
- Added hwdont_run, disable items that might be re-enabled on update

* Thu Oct 12 2006 Earl Sammons <esammons@hush.com>
- Remove non-working DriveInitialization.sh and DriveReInit.sh

* Tue Oct 10 2006 Earl Sammons <esammons@hush.com>
- Fixed oinkmaster config location in hwruleupdate
- Going back to restarting everything on update (the only reliable way)
- Implimented fixes for #508 and #509

* Fri Oct 06 2006 Earl Sammons <esammons@hush.com>
- Changed ChangeSSHPort.sh to UpdateFWSSHPort.sh

* Thu Oct 05 2006 Earl Sammons <esammons@hush.com>
- Added /dlg/config/ChangeSSHPort.sh (#473)
- Addedd above to sudoers file hack

* Fri Sep 01 2006 Earl Sammons <esammons@hush.com>
- Set TMPDIR back to /tmp in /etc/init.d/hwfuncs.sub
- Added snortrule update calls to HoneyAdmin menu
- Completed snortrule_config.sh and snortrule_cron.sh
- Added temp hack to create HwRULE/OINKCODE Vars so nothing chokes
- No longer stopping ALL Hw services in %pre then starting in %post,
   testing restarting of only rc.firewall, bridge and swatch in %post

* Wed Aug 30 2006 Earl Sammons <esammons@hush.com>
- Added snortrules_cron.sh to dialog 
- Added HwRULE_HOUR, HwRULE_DAY, and HwRULE_ENABLE to Makefile.hwctl

* Wed Aug 30 2006 Earl Sammons <esammons@hush.com>
- changed hwrun to hwruleupdate and added to sudoers

* Sun Aug 20 2006 Earl Sammons <esammons@hush.com>
- Added hw_build_ssh_config.sh

* Sun Aug 20 2006 Earl Sammons <esammons@hush.com>
- #462 Changed perms on hwfuncs.sub back to 0755
- #465, #466, #467 Updated sudoers addition and check logic
- #473 Had to add file hw_build_ssh_config.sh and to sudoers

* Wed Aug 16 2006 Earl Sammons <esammons@hush.com>
- Add ALL files to %files along with explicit premissions
- Moved fence/white/blacklsit files back to /etc
- Removed silly fence/white/bleacklist if then copy script
- Commented out legacy updates that convert old NAT variables
- Misc cleanup

* Tue Jul 11 2006 Earl Sammons <esammons@hush.com>
- Split legacy repos into individual files for easier auto enable

* Wed Jul 05 2006 Earl Sammons <esammons@hush.com>
- Added hwrun to configure IPS rules

* Sun Apr 16 2006 Earl Sammons <esammons@hush.com>
- Added RPM keys and import script

* Sat Apr 15 2006 Earl Sammons <esammons@hush.com>
- Added legacy repo config, disabled all repos except honeynet
- Added /hw/etc/logrotate.d + confs and fix to make logrotate look there

* Mon Dec 19 2005 Earl Sammons <esammons@hush.com>
- Cahnged reference from sendmail to postfix in hwfuncs.sub

* Tue Dec 13 2005 Earl Sammons <esammons@hush.com>
- Excluding perl-GD in all repos except ours
- We now maintain perl-GD to ensure png support

* Fri Sep 30 2005 Earl Sammons <esammons@hush.com>
- Attempt to fix host/domain name changing in dialog

* Tue Aug 30 2005 Earl Sammons <esammons@hush.com> 1.0.hw-378
- Fixed snort log dirs perms in lockdown so DM can read snort logs
- Moved fence/white/blacklist files to /hw to avoid overwrite on update

* Wed Aug 24 2005 Earl Sammons <esammons@hush.com> 1.0.hw-356
- Removed cfgtool

* Mon Aug 22 2005 Earl Sammons <esammons@hush.com> 1.0.hw-347
- Added lines to /etc/sudoers for Camilo

* Sun Aug 21 2005 Earl Sammons <esammons@hush.com> 1.0.hw-346
- Placed cfgtool in /usr/local/bin mode 0644 to get it in cvs

* Thu Aug 18 2005 Earl Sammons <esammons@hush.com> 1.0.hw-345
- Made hwdaemons start/stop() work like hw_start/stopHoneywall
- Added complete path to hwctl (which was newly added to hwdaemons)

* Tue Aug 09 2005 Earl Sammons <esammons@hush.com> 1.0.hw-329
- Updated docs in /hw/docs as per Lance.  Please refer to:
- http://www.honeynet.org/tools/cdrom/roo/manual/ 
- for manual until further notice

* Tue Jul 26 2005 Earl Sammons <esammons@hush.com> 1.0.hw-307
- Added if upgrade; then 'hwdaemons stop/start'
- Added /usr/local/bin/hwreset_tally.sh + cron

* Fri Jul 15 2005 Earl Sammons <esammons@hush.com> 1.0.hw-286
- Added blank white/black/fence list files from Kostas/Dave

* Thu Jul 14 2005 Earl Sammons <esammons@hush.com> 1.0.hw-284
- Moved chmod/chown /etc/sudoers so it will run every time to fix bad perms issue

* Wed Jul 13 2005 Earl Sammons <esammons@hush.com> 1.0.hw-277
- Addedd chkconfig --add swatch.sh to %post (Fix #266)

* Wed Jul 13 2005 Earl Sammons <esammons@hush.com> 1.0.hw-278
- Addedd stop/start swatch.sh if this is an upgrade 



