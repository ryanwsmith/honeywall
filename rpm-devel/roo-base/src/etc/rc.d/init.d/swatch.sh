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

# swatch.sh   Starts swatch
#
# chkconfig: 2345 75 30
# description:swatch is a perl based log watcher
#
# processname: swatch.sh
# config: /etc/swatchrc
# pidfile: /var/run/swatch.pid
#
# $Id: swatch.sh 5189 2007-03-13 17:54:21Z esammons $
#
# PURPOSE: To create a swatchrc if it does not exist, and to start swatch
#          to enable monitoring /var/log/iptables based on the configuration
#          defined within swatchrc
#

. /etc/rc.d/init.d/hwfuncs.sub
. /etc/init.d/functions

# Make sure the honeywall is configured before trying to start swatch.
[ $(hw_isconfigured) -eq 0 ] && exit 0

hw_setvars

CONFFILE="/etc/swatchrc"

create_swatchrc() {

#-----------Begin here document---------------
cat > $CONFFILE <<TOFILE
watchfor /OUTBOUND TCP/
mail=${HwALERT_EMAIL},subject=------ ALERT! OUTBOUND TCP --------
throttle 10:0:0

watchfor /OUTBOUND UDP/
mail=${HwALERT_EMAIL},subject=------ ALERT! OUTBOUND UDP --------
throttle 10:0:0

watchfor /OUTBOUND ICMP/
mail=${HwALERT_EMAIL},subject=------ ALERT! OUTBOUND ICMP --------
throttle 10:0:0

watchfor /OUTBOUND OTHER/
mail=${HwALERT_EMAIL},subject=------ ALERT! OUTBOUND OTHER --------
throttle 10:0:0

watchfor /Drop/
mail=${HwALERT_EMAIL},subject=------ ALERT! Connection Limit Reached --------
throttle 10:0:0
TOFILE
#-----------End here document---------------
}

start() {
   if [ -f /var/run/swatch.pid ]; then
       echo  "Swatch already started."
       exit 1
   fi
   #Start alerting if selected
   if [ -n ${HwALERT} ] && [ "${HwALERT}" = "yes" ]; then
      #Create a default swatchrc file if one does not exists.
      if [ ! -f ${CONFFILE} ]; then
         create_swatchrc ${CONFFILE}
      else
         /dlg/config/ChangeEmail.pl
      fi
   
      #launch swatch
      /usr/bin/swatch --config-file=${CONFFILE} --tail-file=/var/log/iptables --pid-file=/var/run/swatch.pid --daemon
      action $"Starting Swatch: " /bin/true
   fi
}

stop() {
	killproc swatch >/dev/null
        killproc tail >/dev/null
	RETVAL=$?
	[ $RETVAL -eq 0 ] && rm -f /var/run/swatch.pid
        action $"Stopping Swatch: " /bin/true
	return $RETVAL
}	

status() {
	if [ -f /var/run/swatch.pid ]; then
		P=`cat /var/run/swatch.pid`
		ps -p $P > /dev/null
		if [ $? -eq 0 ]; then
			echo "swatch (pid $P) is running..."
		else
			echo "swatch appears dead, but a pid file exists"
			exit 1
		fi
	else
		echo "swatch is stopped"
	fi
}

restart() {
  	stop
	start
}	

case "$1" in
  start)
  	start
	;;
  stop)
  	stop
	;;
  status)
	status
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


