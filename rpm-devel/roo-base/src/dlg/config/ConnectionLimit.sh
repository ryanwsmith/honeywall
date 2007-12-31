#!/bin/bash
#
# $Id: ConnectionLimit.sh 2073 2005-08-24 04:04:58Z patrick $
#
# PURPOSE: Allows the user to change the connection limits set on honeypot
#          outbound connections.
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

. /etc/rc.d/init.d/hwfuncs.sub

changed=no

hw_setvars

while true
do

if [ "$changed" == "no" ]; then

   _res=$(dialog --stdout --no-shadow --no-cancel --item-help\
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "          Connection Limiting" 15 50 7\
      back "Return to Previous Menu" "Return to Previous Menu" \
      1 "Scale" "Unit of measurement used (second, minute, hour, day, month)."\
      2 "TCP Limit" "How many outbound TCP connections are allowed per ${HwSCALE}."\
      3 "UDP Limit" "How many outbound UDP connections are allowed per ${HwSCALE}."\
      4 "ICMP Limit" "How many outbound ICMP connections are allowed per ${HwSCALE}."\
      5 "All Other Protocol Limit" "Outbound non-standard IP connections per ${HwSCALE}." )

else

   _res=$(dialog --stdout --no-shadow --no-cancel --item-help\
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "          Connection Limiting" 15 50 7\
      save "Commit Changes and Return to Previous Menu" "Commit Changes" \
      cancel "Cancel Changes and Return to Previous Menu" "Cancel Changes" \
      1 "Scale" "Unit of measurement used (second, minute, hour, day, month)."\
      2 "TCP Limit" "How many outbound TCP connections are allowed per ${HwSCALE}."\
      3 "UDP Limit" "How many outbound UDP connections are allowed per ${HwSCALE}."\
      4 "ICMP Limit" "How many outbound ICMP connections are allowed per ${HwSCALE}."\
      5 "All Other Protocol Limit" "Outbound non-standard IP connections per ${HwSCALE}." )

fi

   case ${_res} in
      1)
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Connection Limiting Configuration" --clear \
                 --inputbox " What scale would you like to use? (second, minute, hour, day, month)" 10 45 ${HwSCALE})
 
         if [ "$?" -eq 0 ]; then
            if [ "$tmp" != "${HwSCALE}" ]; then
              changed=yes
              HwSCALE="$tmp"
            fi
         fi
         ;;

      2)
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Connection Limiting Configuration"  --clear \
                 --inputbox " Enter TCP Limit" 10 45 ${HwTCPRATE})

         if [ "$?" -eq 0 ]; then
            if [ "$tmp" != "${HwTCPRATE}" ]; then
               changed=yes
               HwTCPRATE="$tmp"
            fi
         fi
         ;;

      3)
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Connection Limiting Configuration"  --clear \
                 --inputbox " Enter UDP Limit" 10 45 ${HwUDPRATE})

         if [ "$?" -eq 0 ]; then
            if [ "$tmp" != "${HwUDPRATE}" ]; then
               changed=yes
               HwUDPRATE="$tmp"
            fi
         fi
         ;;

      4) 
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Connection Limiting Configuration"  --clear \
                 --inputbox " Enter ICMP Limit" 10 45 ${HwICMPRATE})

         if [ "$?" -eq 0 ]; then
            if [ "$tmp" != "${HwICMPRATE}" ]; then
               changed=yes
               HwICMPRATE="$tmp"
            fi
         fi
         ;;

      5)
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Connection Limiting Configuration"  --clear \
                 --inputbox " Enter Limit for all other protocols" 10 45 ${HwOTHERRATE})
         
         if [ "$?" -eq 0 ]; then
            if [ "$tmp" != "${HwOTHERRATE}" ]; then
               changed=yes
               HwOTHERRATE="$tmp"
            fi
         fi
         ;;

      save)
         hw_set HwSCALE "$HwSCALE"
         hw_set HwTCPRATE "$HwTCPRATE"
         hw_set HwUDPRATE "$HwUDPRATE"
         hw_set HwICMPRATE "$HwICMPRATE"
         hw_set HwOTHERRATE "$HwOTHERRATE"
         hwctl -r
	 exit 0
         ;;

      cancel)
         exit 0
         ;;

      back)
         exit 0
         ;;
   esac
done

# NOTREACHED (but exit with a value anyway, just for good programming form.)
exit 0
