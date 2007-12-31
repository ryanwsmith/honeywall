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
# $Id: monit.sh 5188 2007-03-13 17:54:02Z esammons $
#
# chkconfig: - 98 02
# description: Monit Process Monitor (honeywall version)
#
# processname: monit
# config: /etc/monitrc
# pidfile: /var/run/monit.pid
#
# PURPOSE: To start and stop the monit process monitor.

. /etc/rc.d/init.d/hwfuncs.sub

# Source function library.
. /etc/rc.d/init.d/functions

# Check to see if the honeywall is configured before trying to
# start monit.
[ $(hw_isconfigured) -eq 0 ] && exit 0

monit=/usr/bin/monit
STATEFILE="$(hw_mktemp monit)"
#LOGFILE="$LOGDIR/monitlog"
LOGFILE="/var/log/monitlog"
OPTIONS="-s $STATEFILE -l $LOGFILE"

start() {
    daemon $monit $OPTIONS
    RETVAL=$?
    echo
    if [ $RETVAL = 0 ] ; then
       touch /var/lock/subsys/monit
       action "Starting monit: " /bin/true
    else
       action "Starting monit: " /bin/false
       RETVAL=1
    fi
    return $RETVAL
}

stop() {
    /usr/bin/monit quit
    RETVAL=$?
    if [ $RETVAL = 0 ] ; then
       action "Stopping monit: " /bin/true
       rm -f /var/lock/subsys/monit
    else
       action "Stopping monit: " /bin/false
       RETVAL=1
    fi
    return $RETVAL
}	

case "$1" in
  start)
  	start
	;;
  stop)
  	stop
	;;
  status)
        status monit
        exit $?
        ;;
  restart)
        stop
        start	
	;;
  *)
	echo $"Usage: $0 {start|stop|status|restart}"
	exit 1
esac

exit $?
