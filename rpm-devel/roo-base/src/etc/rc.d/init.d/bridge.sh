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
# $Id: bridge.sh 5183 2007-03-13 17:51:05Z esammons $
#
# chkconfig: 2345 09 88
# description: Activates/Deactivates the bridge per user configuration.

PATH="/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin"

. /etc/rc.d/init.d/functions
. /etc/rc.d/init.d/hwfuncs.sub

hw_setvars

# Check that the honeywall is configured before trying to start
# the bridge.
[ $(hw_isconfigured) -eq 0 ] && exit 0

start ()
{
   if [ -z "${HwHPOT_PRIV_IP_FOR_NAT}"]; then   #if bridge mode

      #########
      # Let's make sure our interfaces don't have ip information
      #
      ifconfig ${HwINET_IFACE} 0.0.0.0 up -arp
      ifconfig ${HwLAN_IFACE} 0.0.0.0 up -arp

      #########
      # Let's start the bridge
      #
      brctl addbr br0
      brctl addif br0 ${HwLAN_IFACE}
      brctl addif br0 ${HwINET_IFACE}

      # Let's make sure our bridge is not sending out
      #   BPDUs (part of the spanning tree protocol).
      brctl stp br0 off

      # Let's bring up the bridge so it starts working.
      ifconfig br0 0.0.0.0 up -arp

      # Fake a pid file.
      echo "UP" > /var/run/bridge.sh.pid
      touch /var/lock/subsys/bridge.sh

      action $"Starting up Bridging mode: " /bin/true
  fi
}
stop ()
{
   if [ -z  "${HwHPOT_PRIV_IP_FOR_NAT}" ]; then   #if bridge mode
      brctl delif br0 ${HwINET_IFACE} 2> /dev/null
      brctl delif br0 ${HwLAN_IFACE} 2> /dev/null
      # Why set arp?  We don't want them to respond to ARP.
      #ifconfig ${HwINET_IFACE} arp 2> /dev/null
      #ifconfig ${HwLAN_IFACE} arp 2> /dev/null
      ifconfig ${HwINET_IFACE} down
      ifconfig ${HwLAN_IFACE} down
      ifconfig br0 down 2> /dev/null
      brctl delbr br0 2> /dev/null
      rm -f /var/run/bridge.sh.pid
      rm -f /var/lock/subsys/bridge.sh
      action $"Stopping Bridging mode: " /bin/true
   fi
}


case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        brctl show
        ;;
    *)
        echo $"Usage: $0 {start|stop|restart|status)"
esac

exit 0
