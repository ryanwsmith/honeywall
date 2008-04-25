#!/bin/bash
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

#
# $Id: DirectoryCleanup.sh 4566 2006-10-18 17:03:24Z esammons $
#
# PURPOSE: Used to clean out old honeywall directories in order to make 
#          room for additional data.

. /etc/rc.d/init.d/hwfuncs.sub
hw_setvars

/usr/bin/dialog --no-shadow \
        --backtitle "$(hw_backtitle)" \
        --title "Clean out Honeywall directories?"  --defaultno --clear \
        --yesno "Delete honeywall log files in ${LOGDIR} except for Pcap Data?" 15 45

case $? in
    0)
    echo "Beginning Honeywall directory cleanup."

    /etc/init.d/hwdaemons log_cleanout_stop

    for dir in snort snort_inline argus
    do
        if [ -d $LOGDIR/$dir ]; then
            echo -n "Removing everything in $LOGDIR/$dir ..."
            rm -rf $LOGDIR/$dir/*
            echo "Done."
	fi
    done

    /etc/init.d/hwdaemons log_cleanout_start

    echo "Removing Firewall Log ${LOGDIR}/iptables"
    mv ${LOGDIR}/iptables ${LOGDIR}/iptables.old
    rm -f ${LOGDIR}/iptables.old
    /bin/kill -HUP syslogd

    echo "Done"
    echo 'Honeywall directory cleanup successful.'
    echo
    echo "Press any key to return to menu"
    read foo

    exit 0
    ;;

  *) exit 0 ;; 
esac

