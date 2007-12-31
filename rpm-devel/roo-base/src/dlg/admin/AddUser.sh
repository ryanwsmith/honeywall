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
# $Id: AddUser.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: Used to add a user to the system

. /etc/rc.d/init.d/hwfuncs.sub
hw_setvars

NEWUSER=$(/usr/bin/dialog --stdout --no-shadow \
             --backtitle "$(hw_backtitle)" \
             --title "Adding a new user"  --clear \
             --inputbox "We will need to add a user.  Enter the username" 10 45)

#Add the user
/usr/sbin/useradd -m ${NEWUSER}

#Change the Password
/dlg/admin/Password.sh ${NEWUSER}

exit 0
