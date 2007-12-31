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
# $Id: FenceList.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: Used to configure the outbound fence list variables. 

. /etc/rc.d/init.d/hwfuncs.sub

PATH=${PATH}:/usr/bin:/bin
DEFAULT_FENCE=/etc/fencelist.txt

hw_setvars
if [ -z "${HwFWFENCE}" ]; then
    hw_set HwFWFENCE "${DEFAULT_FENCE}"
fi

while true 
do
   hw_setvars
   _res=$(dialog --stdout --no-shadow --no-cancel --item-help \
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "  Outbound Fence List Variables" 20 50 5\
      1 "Back to Honeywall Configuration menu" "Previous menu" \
      2 "Fence List Filename" "File containing ip or network to log and drop." \
      3 "Enable/Reload Fence List" "Enables the list filtering."\
      4 "Disable Fence List" "Disables the list filtering.")

   case ${_res} in
      1) 
         hwctl -r
         exit 0
         ;;
      2)
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Fence List Filename"  --clear \
                 --inputbox " Enter the filename containing the IP addresses or CIDR blocks to drop and ignore" 10 45 ${HwFWFENCE})

         if [ "$?" -eq 0 ]; then
            hw_set HwFWFENCE "$tmp"
            export HwFWFENCE="$tmp"
         fi
         ;;

      3)
         if [ -e "$HwFWFENCE" ]; then
 #            /dlg/config/createWhiteRules.pl
 #            /dlg/config/createBPFFilter.pl
             hw_set HwFENCELIST_ENABLE yes
             export HwFENCELIST_ENABLE=yes
         fi
         ;;
      4)
         hw_set HwFENCELIST_ENABLE no
         export HwFENCELIST_ENABLE=no
         ;;
   esac
done

# NOTREACHED (but exit with a value anyway for good programming form.)
exit 0
