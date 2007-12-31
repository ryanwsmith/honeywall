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
# $Id: RoachMotel.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: Used to configure 'Roach Motel' mode.

. /etc/rc.d/init.d/hwfuncs.sub

PATH=${PATH}:/usr/bin:/bin

while true 
do
   if [ "$(hw_get HwROACHMOTEL_ENABLE)" = "yes" ]; then
       default=ENABLED
   else
       default=DISABLED
   fi
   _res=$(dialog --stdout --no-shadow --no-cancel --item-help \
      --backtitle "$(hw_backtitle)" \
      --title "Roach Motel Mode Configuration"  --clear \
      --menu "  Enable/Disable 'Roach Motel' mode (current this mode is $default)" 20 50 5 \
      1 "Back to Honeywall Configuration menu" "Previous menu" \
      2 "Enable Roach Motel mode" "Enables blocking all outbound traffic from honeypots."\
      3 "Disable Roach Motel mode" "Disables blocking all outbound traffic from honeypots.")

   case ${_res} in
      1)
         # Make any changes take effect.
         hwctl -r 
         exit 0
         ;;
      2)
         hw_set HwROACHMOTEL_ENABLE yes
         ;;
      3)
         hw_set HwROACHMOTEL_ENABLE no
         ;;
   esac
done

# NOTREACHED (but exit with a value anyway for good programming form.)
exit 0
