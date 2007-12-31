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
# $Id: BlackWhite.sh 4714 2006-11-06 14:33:29Z esammons $
#
# PURPOSE: Used to configure the Black and White list variables. 
#          (We should probably separate out Black list from White list
#          filtering so they are independant, rather than doing both
#          or neither. dittrich 02/16/05)

. /etc/rc.d/init.d/hwfuncs.sub

PATH=${PATH}:/usr/bin:/bin
DEFAULT_BLACK=/etc/blacklist.txt
DEFAULT_WHITE=/etc/whitelist.txt

while true 
do
   # Set environment variables for all current variables.
   # (This is probably overkill, since we only need two variables)
   hw_setvars
   # Now enforce defaults, if none already set
   if [ -z "${HwFWBLACK}" ]; then
       export HwFWBLACK="${DEFAULT_BLACK}"
   fi
   if [ -z "${HwFWBLACK}" ]; then
       HwFWBLACK="${DEFAULT_BLACK}"
   fi

   _res=$(dialog --stdout --no-shadow --no-cancel --item-help \
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "Black and White List Variables and BPF Filtering" 20 50 7\
      1 "Back to Honeywall Configuration menu" "Previous menu" \
      2 "Black List Filename" "File containing ip or network to drop and ignore." \
      3 "White List Filename" "File containing ip or network to ignore."\
      4 "Enable Black and White List" "Enables list filtering (IPTables Only)."\
      5 "Disable Black and White List" "Disables list filtering (IPTables Only)."\
      6 "Enable BPF Filtering" "Enables BPF filtering for traffic capture."\
      7 "Disable BPF Filtering" "Disables BPF filtering for traffic capture.")

   case ${_res} in
      1) exit 0
         ;;

      2)
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Black List Filename"  --clear \
                 --inputbox " Enter the filename containing the ips or networks to drop and ignore" 10 45 ${HwFWBLACK})

         if [ "$?" -eq 0 ]; then
            hw_set HwFWBLACK "$tmp"
         fi
         ;;

      3) 
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "White List Filename"  --clear \
                 --inputbox " Enter the filename containing the ips or networks to ignore" 10 45 ${HwFWWHITE})

         if [ "$?" -eq 1 ]; then
            hw_set HwFWWHITE "$tmp"
         fi
         ;;
      4)
         if [ -e "$HwFWWHITE" ] || [ -e "$HwFWBLACK" ]; then
             /dlg/config/createWhiteRules.pl
             /dlg/config/createBlackRules.pl
             /dlg/config/createBPFFilter.pl
             hw_set HwBWLIST_ENABLE yes

             /etc/rc.d/init.d/rc.firewall restart
             /etc/rc.d/init.d/hflow-pcap restart
             /etc/rc.d/init.d/hflow-snort restart
         fi
         ;;
      5)
         hw_set HwBWLIST_ENABLE no

         /etc/init.d/rc.firewall restart
         /etc/rc.d/init.d/hflow-pcap restart
         /etc/rc.d/init.d/hflow-snort restart
         ;;
      6)
         hw_set HwBPF_DISABLE no
	;;
      7)
         hw_set HwBPF_DISABLE yes
	;;
   esac
done

# NOTREACHED (but exit anyway for good programming form.)
exit 0
