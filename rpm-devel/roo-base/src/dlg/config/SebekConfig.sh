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
# $Id: SebekConfig.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: To tell the firewall how to handle sebek packets.

. /etc/rc.d/init.d/hwfuncs.sub

# No matter how we exit, if we changed any SEBEK variables, we
# likely need to restart sebekd and reset firewall rules.
# Call this function to do that in all places.
_exit() {
# EWS_HACK (Doing this now in HoneyConfig.sh because it was 
# stoping unconfigured services on an initial setup
#    hwctl -r
    exit $1
}

PATH=/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/bin

if [ $(hw_isconfigured) -eq 0 ]; then
   if [ "$#" -eq 0 ]; then
      dialog --no-shadow \
         --backtitle "$(hw_backtitle)" \
         --title "Configure Sebek Variables"  --clear \
         --msgbox "This Honeywall has not been configured.  Please run Initial Setup from the main menu.  \
                   Then use this option to configure your sebek variables." 10 60
      _exit 1
   fi
fi

tmp="${HwSEBEK}"
dialog --stdout --no-shadow \
   --backtitle "$(hw_backtitle)" \
   --title "Configure Sebek Variables"  --clear \
   --yesno "This option will allow you to configure how the Honeywall handles your sebek packets.  You will be able to tell the firewall how to identify your sebek packets, and you will be able to tell it how to route them.  Would you like to configure sebek variables at this time?" 11 55
if [ "$?" -eq 0 ]; then
   hw_set HwSEBEK yes
else
   hw_set HwSEBEK no
   _exit 0
fi

_tmp=$(dialog --stdout --no-shadow \
   --backtitle "$(hw_backtitle)" \
   --title "Configure Sebek Variables"  --clear \
   --inputbox "Enter the destination IP address of the sebek packets." 10 45 "${HwSEBEK_DST_IP}")

if [ "$?" -eq 0 ]; then
   hw_set HwSEBEK_DST_IP "$_tmp"
else
   hw_set HwSEBEK no
   _exit 0
fi

_tmp=$(dialog --stdout --no-shadow \
   --backtitle "$(hw_backtitle)" \
   --title "Configure Sebek Variables"  --clear \
   --inputbox "Enter the destination udp port of the sebek packets." 10 45 "${HwSEBEK_DST_PORT}")

if [ "$?" -eq 0 ]; then
   hw_set HwSEBEK_DST_PORT "$_tmp"
else
   hw_set HwSEBEK no
   _exit 1
fi

_opt=$(dialog --stdout --no-shadow --stdout --clear --item-help\
          --backtitle "$(hw_backtitle)" \
          --title "Configure Sebek Variables" \
          --menu "    Sebek Packet Options" 10 40 4 \
          1 "Drop" "Drop sebek packets.  Don't worry, snort will still see these."\
          2 "Drop and Log" "Same as Drop, and the packet is logged in the firewall logs."\
          3 "Accept" "Accept sebek packets.  This is required if you want them to route."\
          4 "Accept and Log" "Same as accept, and the packet is logged in the firewall logs.")

case ${_opt} in
   1) hw_set HwSEBEK_FATE DROP
      hw_set HwSEBEK_LOG no
      ;;
   2) hw_set HwSEBEK_FATE DROP
      hw_set HwSEBEK_LOG yes
      ;;
   3) hw_set HwSEBEK_FATE ACCEPT
      hw_set HwSEBEK_LOG no
      ;;
   4) hw_set HwSEBEK_FATE ACCEPT
      hw_set HwSEBEK_LOG yes
      ;;
esac

_exit 0
