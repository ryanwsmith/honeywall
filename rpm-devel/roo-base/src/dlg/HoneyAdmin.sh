#!/bin/bash
#
# $Id: HoneyAdmin.sh 4449 2006-09-28 19:41:23Z esammons $
#
# PURPOSE: Allows user to perform Honeywall Administration options.
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
PATH=/usr/bin:/bin:/sbin

while true
do
   hw_setvars

   _res=$(dialog --stdout --no-cancel --item-help --clear \
          --backtitle "$(hw_backtitle)" \
          --title "Honeywall Administration" --clear \
          --menu "Honeywall Administration Options" 18 45 12 \
          back "Return to main menu" "Return to main menu" \
          1 "Manage configuration subsystem" "Play with honeywall.conf" \
          2 "Emergency Lockdown!" "Deactivate the Honeywall (Bridge)" \
          3 "Re-activate Honeywall" "Re-activate ALL HW Services (i.e. after Emergency Lockdown)" \
          4 "Restart Honeywall" "Force restart of rc.firewall" \
          5 "Reload Honeywall" "Reload rc.firewall, snort, snort_inline" \
          6 "Reload IDS Snort" "Reloads IDS version of snort" \
          7 "Reload Pcap Snort" "Reloads data capture version of snort" \
          8 "Reload Snort-Inline" "Reloads snort_inline" \
	  9 "Update Snort Rules" "Updates snort IDS and IPS rules" \
	 10 "Update IDS rules" "Only updates snort IDS rules" \
	 11 "Generate IPS rules" "Generates snort IPS rules from existing IDS rules")
   case ${_res} in
      back)
         exit 0
         ;;
      1)
        # Is this honeywall configured yet?
         if [ $(hw_isconfigured) -eq 1 ]; then
            /dlg/admin/MakeConfigs.sh
         else
             /usr/bin/dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Manage Configuration Subsystem" \
                --msgbox "   This Honeywall is not yet configured." 15 45 
            exit 0
         fi
         ;;
      2)
         _tmp=`/etc/init.d/rc.firewall status`
         if [ $? -eq 0 ]; then 
            # Shouldn't this also do the following?
            # (Should we invert the order, like shown below,
            # for stopping things?)
            #
            #if [ "${HwQUEUE}" = "yes" ]; then
            #   /etc/init.d/hflow-snort_inline stop
            #fi
            #/etc/init.d/hflowd      stop
            #/etc/init.d/hflow-argus stop
            #/etc/init.d/sebekd      stop
            #/etc/init.d/hflow-p0f   stop
            #/etc/init.d/hflow-pcap  stop
            #/etc/init.d/hflow-snort stop
            /etc/init.d/rc.firewall lockdown
            #/etc/init.d/hwdaemons lockdown
         else 
             /usr/bin/dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Honeywall stop failed" \
                --msgbox "   This Honeywall is not active." 15 45 
         fi
         ;;
      3)
            /etc/init.d/hwdaemons restart
         ;;
      4) 
         # How come, when eeyore started/stopped snort and snort_inline
         # in conjunction with rc.firewall, do we not do that here, too?
         # And if so, what is the difference between this and the next
         # option?

         _tmp=`/etc/init.d/rc.firewall status`
         if [ $? -eq 0 ]; then 
            /etc/init.d/rc.firewall restart
         else 
             /usr/bin/dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Honeywall restart failed" \
                --msgbox "   This Honeywall is not active, so it can't be restarted.  Activate the honeywall first." 15 45 
         fi
         ;;
      5)
         /etc/init.d/rc.firewall restart
         /etc/init.d/hflow-snort restart
         /etc/init.d/hflow-pcap  restart
	 /etc/init.d/hflow-p0f   restart
	 /etc/init.d/sebekd      restart
	 /etc/init.d/hflow-argus restart
	 /etc/init.d/hflowd      restart
         if [ "${HwQUEUE}" = "yes" ]; then
            /etc/init.d/hflow-snort_inline restart
         fi
         ;;
      6) #reload snort
         /etc/init.d/hflow-snort restart
         ;;
      7) #reload pcap snort
         /etc/init.d/hflow-pcap restart
         ;;
      8) #reload snort_inline
         if [ "${HwQUEUE}" = "yes" ]; then
            /etc/init.d/hflow-snort_inline restart
         fi
         ;;
      9) #Update snort IDS and IPS rules, (restarts both)
	/hw/sbin/hwruleupdate --update-rules
	;;
     10) # Update only IDS rules, (restart snort)
	/hw/sbin/hwruleupdate --update-rules-ids
	;;
     11) #Create IPS rules from IDS rules, (restarts snort_inline)
	/hw/sbin/hwruleupdate --snortconfig
	;;
   esac
done
