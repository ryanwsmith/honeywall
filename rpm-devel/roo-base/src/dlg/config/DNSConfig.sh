#!/bin/bash
#
# $Id: DNSConfig.sh 2073 2005-08-24 04:04:58Z patrick $
#
# PURPOSE: To allow the user to configure how the honeywall will treat honeypot
#          outbound dns traffic.  Basically, tells the firewall if it should
#          be counted as a new connection or if outbound dns should be allowed
#          and not counted.
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

PATH=$PATH:/usr/bin:/bin

changed=no

hw_setvars

while true
do

if [ "$changed" == "no" ]; then
   _res=$(dialog --stdout --no-shadow --no-cancel --item-help\
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "          DNS Handling" 10 60 4\
      back "Return to Previous Menu" "Return to Previous Menu" \
      1 "Honeypot(s) allowed unlimited external DNS" "Space delimited list of honeypots allowed un-restricted outbound DNS."\
      2 "Valid external DNS Servers " "Space delimited list of DNS server that can be queried by the honeypots. " )

else

   _res=$(dialog --stdout --no-shadow --no-cancel --item-help\
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "          DNS Handling" 10 60 4\
      save "Commit Changes and Return to Previous Menu" "Commit Changes" \
      cancel "Cancel Changes and Return to Previous Menu" "Cancel Changes" \
      1 "Honeypot(s) allowed unlimited external DNS" "Space delimited list of honeypots allowed un-restricted outbound DNS."\
      2 "Valid external DNS Servers " "Space delimited list of DNS server that can be queried by the honeypots. " )

fi

   case ${_res} in
      1)
         tmp=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "DNS Handling"  --clear \
            --inputbox "   Enter a space delimited list of Honeypot(s) that can access external DNS servers?" 10 45 "${HwDNS_HOST}")

         if [ "$?" -eq 0 ]; then
           if [ "$tmp" != "${HwDNS_HOST}" ]; then
              changed=yes
              HwDNS_HOST="$tmp"
           fi
         fi
         ;;

      2)
         tmp=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "DNS Configuration"  --clear \
            --inputbox "   Enter a space delimited list of DNS Servers" 10 45 "${HwDNS_SVRS}")

         if [ "$?" -eq 0 ]; then
           if [ "$tmp" != "${HwDNS_SVRS}" ]; then
            changed=yes
            HwDNS_SVRS="$tmp"
           fi
         fi
         ;;

      save)
         hw_set HwDNS_HOST "$HwDNS_HOST"
         hw_set HwDNS_SVRS "$HwDNS_SVRS"
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

# NOTREACHED (but exit with a value anyway for good programming form.)
exit 0
