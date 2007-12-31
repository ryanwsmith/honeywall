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
# $Id: dialogmenu.sh 4668 2006-10-26 23:01:24Z esammons $
#
# PURPOSE: The main menu in the user interface to the Honeywall Bootable
#          cdrom.  Everything the user can do via the UI starts here.

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

PATH=/usr/local/bin:$PATH

#Beginning Menu Interface
#This is the root "Main Menu"
hw_setvars

/usr/bin/dialog --title "Honeywall Configuration and Administration" --clear \
                --backtitle "$(hw_backtitle)" \
		--msgbox "\n              ****WARNING****\n\nDo not press \"CTRL+C\" anywhere in this application.  To exit this program, return to the main menu and choose \"Exit\".  Pressing \"CTRL+C\" may kill running applications!\n\n              ****WARNING****" 13 50


while true
do

   _opt=$(/usr/bin/dialog --no-cancel --stdout --clear --item-help\
                --backtitle "$(hw_backtitle)" \
                --title "Honeywall CD" \
                --menu "    Main Menu" 15 40 7 \
                1 "Status" "Check the status of your Honeywall."\
                2 "OS Administration" "Modify or administer the host OS."\
                3 "Honeywall Administration" "Used for the day to day administration of your configured Honeywall" \
                4 "Honeywall Configuration" "Manage the configuration of the Honeywall" \
                5 "Documentation" "Learn how the Honeywall works and how to configure and use it." \
                6 "Exit" "Terminate dialog GUI.")

case ${_opt} in
    1) /dlg/Status.sh
       ;;
    2) /dlg/Administration-menu.sh
       ;;
    3) /dlg/HoneyAdmin.sh
       ;;
    4) /dlg/HoneyConfig.sh
       ;; 
    5) /dlg/ShowDocs.sh /hw/docs
       ;;
    6) clear
       exit 0
       ;;
    *) ;;
esac

done

exit 0
