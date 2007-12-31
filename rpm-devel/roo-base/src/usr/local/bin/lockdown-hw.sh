#!/bin/sh
#
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

# $Id: lockdown-hw.sh 4735 2006-11-07 18:51:02Z esammons $

####################################################################
# lockdown.sh
# An attempt to make our customized FC3 based Honeywall
# meet NIST-DITSCAP baseline security requirements

EXT=$(date +%F)

####################################################################

clear

. /etc/rc.d/init.d/hwfuncs.sub

####################################################################
# Must be root to run this
if [ "${UID}" -ne 0 ]; then
	echo "Error: Must be root"
	exit 1
fi 

####################################################################
#echo "Making sure Shadow passowrds/groups are in use and info is updated..."
/usr/sbin/pwconv
/usr/sbin/grpconv

####################################################################
#TODO: convert to sed -i
#Fix /etc/login.defs
LI_DEFS=/etc/login.defs
sed -i 's/^PASS_MAX_DAYS.*$/PASS_MAX_DAYS 60/' ${LI_DEFS}
sed -i 's/^PASS_MIN_DAYS.*$/PASS_MIN_DAYS 1/' ${LI_DEFS}
sed -i 's/^PASS_MIN_LEN.*$/PASS_MIN_LEN 8/' ${LI_DEFS}

# For passwd re-use
touch /etc/security/opasswd
chmod 0600 /etc/security/opasswd

####################################################################
#TODO: convert to sed -i
# Update PAM system-auth
SYS_AUTH=/etc/pam.d/system-auth
cat > ${SYS_AUTH} <<EOFsysauth
# STIG-ed system-auth
# authoconfig should not be on this system so this should not get overwritten

auth 	required 	pam_env.so
auth 	required 	pam_tally.so onerr=fail no_magic_root
auth	sufficient	pam_unix.so likeauth nullok
auth 	required 	pam_deny.so

account required 	pam_unix.so
account required 	pam_tally.so deny=3 no_magic_root reset

password required 	pam_cracklib.so retry=3 minlen=8 lcredit=-1 ucredit=-1
password sufficient 	pam_unix.so nullok use_authtok md5 shadow remember=10
password required 	pam_deny.so

session	required 	pam_limits.so
session	required 	pam_unix.so

EOFsysauth

chown root:root ${SYS_AUTH}
chmod 0644 ${SYS_AUTH}

####################################################################
#TODO: convert to sed -i
# SSH Sanity checks...
rpm -q --quiet openssh-server
if [ $? -eq 0 ]; then
	# The STIG version of the sshd_config file is now
	# created initially in hw_build_ssh_config() from
	# /etc/rc.d/init.d/hwfuncs.sub.  If the user choses
	# to over-ride the "no remote login" thing, then
	# the warning above no longer applies.
	hw_build_ssh_config
	service sshd restart
fi 

####################################################################
# fix .bash_profile in general user profiles...
for HOME_D in $(ls /home | grep -v "lost+found"); do
  if [ -f ${HOME_D}/.bash_profile ]; then
#    sed -i "s/^PATH.*/PATH=\$PATH/" ${HOME_D}/.bash_profile
    if [ $(grep -c "TMOUT=900" ${HOME_D}/.bash_profile) -eq 0 ]; then 
      echo "export TMOUT=900" >> ${HOME_D}/.bash_profile
    fi
  fi
done
# Same in root and skel dirs...
for prof_dir in /etc/skel /root; do
  if [ -f ${prof_dir}/.bash_profile ]; then
    if [ $(grep -c "TMOUT=900" ${prof_dir}/.bash_profile) -eq 0 ];then 
      echo "export TMOUT=900" >> ${prof_dir}/.bash_profile
    fi
  fi
done

####################################################################
# Fix home dir ownership and perms...
# For all user home dirs...

for user in $(ls /home | grep -v "lost+found"); do
# Make user own all files in their dirs
	if [ -d /home/${user} ]; then
		chown -R ${user}:${user} /home/${user}
# Let no <Other Users> read, write, or exe any of their files
# Let no <Groups> write to any of their files
		chmod 0700 /home/${user}
	        find /home/${user} -type f | xargs chmod o-rwx,g-w
	fi
done

# Same for root
if [ -d /root ]; then
	chown -R root:root /root
	chmod 0700 /root
        find /root -type f | xargs chmod o-rwx
fi

####################################################################
rm -f /root/anaconda-ks.cfg

chmod 0700 /etc/cron.*/*
chmod 0640 /etc/syslog.conf
chmod 0600 /etc/sysctl.conf
chmod 0640 /etc/security/access.conf
####################################################################
ITAB=/etc/inittab
if [ $(grep -c ":S:" /etc/inittab) -gt 0 ]; then
	sed -i "s/^.*:S:.*$/~~:S:wait:\/sbin\/sulogin/" ${ITAB}
else
	echo "~~:S:wait:/sbin/sulogin" >> ${ITAB}
fi

if [ $(grep -c ":ctrlaltdel:" ${ITAB}) -gt 0 ]; then
	sed -i "s/^.*:ctrlaltdel:.*$/ca::ctrlaltdel:\/bin\/false/" ${ITAB}
else
	echo "ca::ctrlaltdel:/bin/false/" >> ${ITAB}
fi
chown root:root ${ITAB}
chmod 0600 ${ITAB}
####################################################################

####################################################################
# Change umask to 077 in /etc/bashrc
BASH_RC=/etc/bashrc

if [ -f ${BASH_RC} ];then 
	if [ $(grep "umask" ${BASH_RC} | grep -vc "077") -gt 0 ]; then
# umask set wrong
		sed -i "s/^\(.*umask\).*$/\1 077/g" ${BASH_RC}
	else 
# hand jam a umask in since there isnt one there at all
		echo "umask 077" >> ${BASH_RC}
	fi
	chown root:root ${BASH_RC}
	chmod 0644 ${BASH_RC}
fi

####################################################################
# Set TMOUT=900, umask 077, msg n in /etc/profile
PROFILE=/etc/profile

if [ -f ${PROFILE} ]; then
	if [ $(grep "TMOUT=" ${PROFILE} | grep -c "900") -lt 0 ]; then
#TMOUT set to something other than 900, fix it
		sed -i "s/^\(.*TMOUT=\).*/\1900/" ${PROFILE}
	elif [ $(grep -c "TMOUT=" ${PROFILE}) -lt 1 ]; then
#No TMOUT=, add it
		sed -i "s/^\(.*export.*\)$/TMOUT=900\n\1/" ${PROFILE}
	fi
# Be sure TMOUT is exported
	if [ $(grep "export" ${PROFILE} | grep -c "TMOUT") -lt 0 ]; then
		sed -i "s/^\(.*export.*\)$/\1 TMOUT/" ${PROFILE}
	fi

	if [ $(grep "umask" ${PROFILE} | grep -vc "077") -gt 0 ]; then
# umask set wrong
		sed -i "s/^\(.*umask\).*$/\1 077/g" ${PROFILE}
	else 
# hand jam a umask in since there isnt one there at all
		echo "umask 077" >> ${PROFILE}
	fi

	if [ $(grep -c "mesg n" ${PROFILE}) -lt 1 ]; then
		echo "mesg n" >> ${PROFILE}
	fi
	chown root:root ${PROFILE}
	chmod 0644 ${PROFILE}
fi

####################################################################
# Dissable system wide core dumps...

LIMITS="/etc/security/limits.conf"
if [ $(grep -c "^\* .*soft .*core .*0" ${LIMITS}) -lt 1 ]; then
	echo "*   soft   core   0" >> ${LIMITS}
fi

if [ $(grep -c "^\* .*hard .*core .*0" ${LIMITS}) -lt 1 ]; then
	echo "*   hard   core   0" >> ${LIMITS}
fi

####################################################################
# Fix /etc/sysctl.conf

#SYSCTL=/etc/sysctl.conf
#if [ -f ${SYSCTL} ]; then
#	if [ $(grep -c "net\.ipv4\.conf\.all\.accept_source_route = 0" ${SYSCTL}) -lt 1 ]; then
#		echo "#PDI: L198" >> ${SYSCTL}
#		echo "net.ipv4.conf.all.accept_source_route = 0" >> ${SYSCTL}
#	fi
#
#	if [ $(grep -c "net\.ipv4\.tcp_max_syn_backlog = 4096" ${SYSCTL}) -lt 1 ]; then
#		echo "#PDI: L200" >> ${SYSCTL}
#		echo "net.ipv4.tcp_max_syn_backlog = 4096" >> ${SYSCTL}
#	fi
#
#	if [ $(grep -c "net\.ipv4\.conf\.all\.rp_filter = 1" ${SYSCTL}) -lt 1 ]; then
#		echo "#PDI: L202" >> ${SYSCTL}
#		echo "net.ipv4.conf.all.rp_filter = 1" >> ${SYSCTL}
#	fi
#	chown root:root ${SYSCTL}
#	chmod 0600 ${SYSCTL}
#fi

####################################################################
# G090 Requires min umask = 077
# I'm afraid that will break thinsg so just change from std installed
# umask of 022 to 027 to at least prevent world writable files from
# being created by things like Syslog etc.
# Must document umask more permissive than 077
FUNCTS="/etc/init.d/functions"
if [ $(grep -c "^umask 027" ${FUNCTS}) -lt 1 ]; then
# No "umask 027"
	if [ $(grep -c "^umask" ${FUNCTS}) -gt 0 ]; then
# Some "umask(s)" other than "027", just clobber them all
		sed -i "s/^umask.*$/umask 027/" ${FUNCTS}
	else
# No umask at all, insert as 1st line (preserve existing 1st line)
		sed -i "1,1s/^\(.*\)$/umask 027\n\1/" ${FUNCTS}
	fi
fi

####################################################################
# Fix umask in /etc/csh.cshrc
CSHRC="/etc/csh.cshrc"

if [ $(grep -c "^umask 077" ${CSHRC}) -lt 1 ]; then
# No "umask 077"
	if [ $(grep -c "^umask" ${CSHRC}) -gt 0 ]; then
# Some "umask(s)" other than "077", just clobber them
		sed -i "s/^umask.*$/umask 077/" ${CSHRC}
	else
# No umask at all, insert as 1st line (preserve existing 1st line)
		sed -i "1,1s/^\(.*\)$/umask 077\n\1/" ${CSHRC}
	fi
fi

####################################################################
#Set up password aging
for NAME in $(cut -f1 -d':' /etc/passwd); do
	NAME_UID=$(id -u ${NAME})
	if [ "${NAME_UID}" -ge 500 ]; then
		/usr/bin/chage -m 1 -M 60 -W 25 ${NAME}
	fi
done

####################################################################
# Fix Permissions and Ownership last...

#Fix snort/snort_inline perms...
#if [ -d /var/log/snort ]; then
#	chown -R snort:snort /var/log/snort
#	chmod 0755 /var/log/snort
#fi
#if [ -f /var/log/snort_inline ]; then
#	chown -R snort:snort /var/log/snort_inline
#	chmod 0755 /var/log/snort_inline
#fi

####################################################################
# Fix various cron file stuff from CIS
chmod 0600 /etc/crontab

####################################################################
# No root login directly...
#echo "Updating /etc/securetty to disable logins on alternate VTs"
SEC_TTY=/etc/securetty
if [ "$(cat ${SEC_TTY} | wc -l)" -gt 1 -o \
     "$(grep -c 'console' ${SEC_TTY})" -ne 1 ]; then
	cp ${SEC_TTY} ${SEC_TTY}.${EXT}
	echo "console" > ${SEC_TTY}
	chown root:root ${SEC_TTY}
	chmod 0600 ${SEC_TTY}
fi
####################################################################
# Delete unecessary users
for user in adm operator games gopher news uucp ftp sync shutdown; do
	/usr/sbin/userdel $user 2> /dev/null
done

for group in adm news uucp games gopher ftp uucp sync shutdown; do
	/usr/sbin/groupdel $group 2> /dev/null
done
####################################################################
# Set "system" shells to /dev/null
# If default = /sbin/nologin therre is still potential for FTP login
# Even though we dont run FTP...
# cis
for userid in bin daemon lp sync shutdown halt mail nobody dbus \
vcsa rpm haldaemon sshd mailnull smmsp pcap apache mysql ntp snort \
distcache xfs; do
      if [ $(grep -c "^${userid}:" /etc/passwd) -gt 0 ]; then
              /usr/sbin/usermod -L -s /dev/null ${userid}
      fi
done
####################################################################
# PDI Number: G086++ nosuid/nodev
# Fix /etc/fstab
FSTAB="/etc/fstab"
# nosuid on /home
if [ $(grep " \/home " ${FSTAB} | grep -c "nosuid") -eq 0 ]; then
	MNT_OPTS=$(grep " \/home " ${FSTAB} | awk '{print $4}')
	sed -i "s/\( \/home.*${MNT_OPTS}\)/\1,nosuid/" ${FSTAB}
fi

####################################################################
rm -f /etc/at.deny
rm -f /etc/cron.deny
echo "root" > /etc/at.allow
echo "root" > /etc/cron.allow
chown root:root /etc/at.allow
chown root:root /etc/cron.allow
chmod 0600 /etc/at.allow
chmod 0600 /etc/cron.allow

####################################################################

# Is apache installed?
rpm -q --quiet httpd
if [ $? -eq 0 ]; then
	for HTTPD_CONF in /etc/httpd/conf/httpd.conf \
		/etc/walleye/httpd.conf; do
		if [ -f ${HTTPD_CONF} ]; then
			chown root:apache ${HTTPD_CONF}
			chmod 0540 ${HTTPD_CONF}
		fi
	done
 	if [ -d /var/www/cgi-bin ]; then
		chmod 0510 /var/www/cgi-bin
	fi
ROBOTS=/var/www/html/robots.txt
cat > ${ROBOTS} <<EOFrobots
User-agent: *
Disallow: /
EOFrobots

	chown apache:apache ${ROBOTS}
	chmod 0640 ${ROBOTS}
fi
####################################################################

#EOF
exit 0


