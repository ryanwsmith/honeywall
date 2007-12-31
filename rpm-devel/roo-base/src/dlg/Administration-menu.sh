#!/bin/bash
#
# $Id: Administration-menu.sh 4521 2006-10-13 13:08:58Z esammons $
#
# PURPOSE: Allows the user to execute specific operating system operations that
#          are not part of the Honeywall configuration or administration.
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

####################################################################
# Must be root to run this
if [ "${UID}" -ne 0 ]; then
        echo ""
        echo "$0: Only \"root\" can run $0"
        echo ""
        exit 1
fi
####################################################################

. /etc/rc.d/init.d/hwfuncs.sub

hw_setvars

while true
do

   #Beginning Admin Menu Interface

   _opt=$(/usr/bin/dialog --stdout --no-cancel --no-shadow --item-help \
          --backtitle "$(hw_backtitle)" \
          --title "OS Administration menu" \
          --menu "   OS Administration Options" 18 48 10 \
          back "Back to main menu" "Returns to main menu" \
	  1 "Clean out logging directories" "Deletes contents of ${LOGDIR}" \
          2 "Configure SSH daemon" "Configure SSH for remote mgmt (only on the mgmt interface)." \
          3 "Change Hostname" "Configure hostname of the system." \
          4 "Add User" "Adds a user to the system." \
          5 "Change Root Password" "Configure the root password of the system."\
          6 "Create Honeywall directories" "Creates Honeywall specific directories on an existing system."\
          7 "Reboot Honeywall" "Reboot the entire system." )

   case ${_opt} in
      back)
          exit 0
          ;;
      1)  /dlg/admin/DirectoryCleanup.sh;;
      2)  /dlg/admin/SSHConfig.sh;;
      3)  tmpHost=$(/bin/hostname)
          newHostname=$(/usr/bin/dialog --stdout --no-shadow \
                        --backtitle "$(hw_backtitle)" \
                        --title "Change Hostname" \
                        --inputbox "   Enter the new Hostname" 15 45 ${tmpHost})

          if [ "$?" -eq 0 ]; then
            if [ "$tmpHost" != "$newHostname" ]; then
	       hw_sethostname ${newHostname}
            fi
          fi
          ;;
      4)  /dlg/admin/AddUser.sh;;
      5)  /dlg/admin/Password.sh;;
      6)  /dlg/admin/DirectoryInitialization.sh;;
      7) /sbin/shutdown -r now;;
   esac
done
