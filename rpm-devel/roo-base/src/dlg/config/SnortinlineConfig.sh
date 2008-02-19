#!/bin/bash
#
# $Id: SnortinlineConfig.sh 4165 2006-08-17 16:00:40Z esammons $
#
# PURPOSE: Allows the user to configure different portions of snort_inline.
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
hw_setvars

PATH=/usr/bin:/bin:/sbin:/usr/sbin

#if [ "${HwINIT_SETUP}" != "done" ]; then
#   if [ "$#" -eq 0 ]; then
#      dialog --no-shadow \
#         --backtitle "$(hw_backtitle)" \
#         --title "Configure snort_inline"  --clear \
#         --msgbox "This Honeywall has not been configured.  Please run Initial Setup from the main menu.  \
#                   Then use this option to configure snort_inline." 10 60
#      exit
#   fi
#fi

_opt=$(dialog --stdout --no-shadow --stdout --clear --item-help\
          --backtitle "$(hw_backtitle)" \
          --title "Configure snort_inline" \
          --menu "    snort_inline Options" 10 40 3 \
          1 "Enable snort_inline" "Sets QUEUE to yes, enables snort_inline, and starts process"\
          2 "Disable snort_inline" "Sets QUEUE to no, disables snort_inline, and kills process")

case ${_opt} in
   1)  hw_set HwQUEUE yes
       /etc/rc.d/init.d/rc.firewall restart
       /etc/rc.d/init.d/hw-snort_inline restart
       ;;
   2)  hw_set HwQUEUE no
       /etc/rc.d/init.d/hw-snort_inline stop
       /etc/rc.d/init.d/rc.firewall restart
       ;;
esac

exit 0 
