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
# $Id: Password.sh 4222 2006-08-20 22:03:28Z esammons $
#
# PURPOSE: Used to change a given users password.  If a user is not given,
#          it assumes you want to change root's password.

. /etc/rc.d/init.d/hwfuncs.sub

PATH=/bin:/sbin:/usr/bin

if [ "$#" -gt 0 ]; then
   _user=$1
else
   _user="root"
fi

while true
do

#   dialog --no-shadow \
#      --backtitle "$(hw_backtitle)" \
#      --title "Change "${_user}" password"  --clear \
#      --yesno "Are you sure you want to change "${_user}"'s password?" 10 45

   dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Change "${_user}" password"  --clear \
      --msgbox " Changing password for \"${_user}\"" 10 45

   if [ $? -eq 1 ]; then
      exit 0
   else
# No, we dont do that anymore...
#      dialog --no-shadow \
#         --backtitle "$(hw_backtitle)" \
#         --title "Change ${_user} password" --clear \
#         --msgbox "Note: Password will be shown on screen!" 10 45

      _firstPass=$(dialog --stdout --no-shadow \
         --backtitle "$(hw_backtitle)" \
         --title "Change "${_user}" password"  --clear --insecure \
         --passwordbox " Enter new password" 10 45)

      if [ "$?" -eq 1 ]; then
         exit 0
      fi

      _secondPass=$(dialog --stdout --no-shadow \
         --backtitle "$(hw_backtitle)" \
         --title "Change "${_user}" password"  --clear --insecure \
         --passwordbox " Enter it again" 10 45)

      if [ "$?" -eq 1 ]; then
         exit 0
      fi

      if [ "${_firstPass}" = "" ]; then
         dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Change "${_user}" password"  --clear \
            --msgbox " The password may not be null.  Please try again." 10 45
      elif [ "${_firstPass}" != "${_secondPass}" ]; then
         dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Change "${_user}" password"  --clear \
            --msgbox " Passwords do not match.  Please try again." 10 45
      else
         echo "${_firstPass}" | passwd ${_user} --stdin
         _firstPass=""
         _secondPass=""
         if [ "$?" -eq 0 ]; then
            dialog --stdout --no-shadow \
               --backtitle "$(hw_backtitle)" \
               --title "Change "${_user}" password"  --clear \
               --msgbox " Password changed!" 10 45
            exit 0
         else
            dialog --stdout --no-shadow \
               --backtitle "$(hw_backtitle)" \
               --title "Change "${_user}" password"  --clear \
               --msgbox " Could not change "${_user}" password!" 10 45
         fi
      fi
   fi
done

exit 0
