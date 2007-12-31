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
# $Id: Summary.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: To allow the user to configure how the honeywall's traffic 
#          summary script

. /etc/init.d/hwfuncs.sub

PATH=$PATH:/usr/bin:/bin

while true
do
   hw_setvars
   _res=$(dialog --stdout --no-shadow --no-cancel --item-help\
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Summary Configuration"  --clear \
      --menu "          Summary Variables" 10 60 2\
      1 "Return to Honeywall Configuration" "Previous menu"\
      2 "Honeynet" "Network to summarize".)

   case ${_res} in
      1) exit 0
         ;;
      2)
         _tmp=$(dialog --stdout --no-shadow \
                  --backtitle "$(hw_backtitle)" \
                  --title "Summary Variables" --clear \
                  --inputbox "Enter the Honeynet to summarize in CIDR format (i.e. 1.1.1.0/24)." 10 45 "${HwSUMNET}")

         if [ "$?" -eq 0 ]; then
            hw_set HwSUMNET "$_tmp"
         fi

         dialog --stdout --no-shadow \
             --backtitle "$(hw_backtitle)" \
             --title "Summary Variables" --clear \
             --msgbox "This and the alert email address will enable the /usr/local/bin/summary.sh script in root's crontab file that is set to execute daily at 0100" 10 50
         ;;
   esac
done

exit 0
