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
# $Id: SSHConfig.sh 4669 2006-10-26 23:03:04Z esammons $
#
# PURPOSE: To configure the ssh service for use on the Honeywall.

. /etc/rc.d/init.d/hwfuncs.sub

/usr/bin/dialog --stdout --no-shadow \
	--backtitle "$(hw_backtitle)" \
	--title "WARNING" --clear \
	--msgbox "WARNING: If you change the SSHD Port, ALL current SSH sessions MIGHT be TERMINATED.  If so, you should be able to re-login on the new SSHD port" 10 45

while true
do
   hw_setvars
   OLD_HwSSHD_PORT="${HwSSHD_PORT}"

   _opt=$(/usr/bin/dialog --stdout --no-shadow --nocancel\
           --backtitle "$(hw_backtitle)" \
           --title "SSH Administration"  --clear \
           --menu "   SSH daemon options" 15 45 5 \
           1 "Back to OS Administration Menu" \
           2 "Listen on port number" \
           3 "Permit remote root login")
   case ${_opt} in
      1)
         exit 0
         ;;

      2)
        _tmp=$(/usr/bin/dialog --stdout --no-shadow --nocancel \
                --backtitle "$(hw_backtitle)" \
                --title "SSHD listening port"  --clear \
                --inputbox "Enter the port SSHD port" 15 45 "${HwSSHD_PORT}")
        if [ $? -eq 0 ]; then
           hwctl -r HwSSHD_PORT="${_tmp}"
        fi
        ;; 

       3)
         /usr/bin/dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "SSHD permit remote root login"  --clear \
                --yesno "Allow root to login remotely?  It is not necessary to allow root to login remotely.  Instead, the honey user can be used to login via SSH and then su to root." 15 45

         if [ $? -eq 0 ]; then
            hwctl -r HwSSHD_REMOTE_ROOT_LOGIN=yes
         else
            hwctl -r HwSSHD_REMOTE_ROOT_LOGIN=no
         fi
         ;;

       *)
         exit 1
         ;;
   esac
done

exit 0
