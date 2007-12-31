#!/bin/bash
#
# $Id: ModeConfig.sh 2073 2005-08-24 04:04:58Z patrick $
#
# PURPOSE: Allows the user to tell the honeywall the specifics about the 
#          network on both sides of the firewall.
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

PATH=${PATH}:/usr/bin:/bin

reset_bridge=no
changed=no

hw_setvars
while true
do

if [ "$changed" == "no" ]; then

   _res=$(dialog --stdout --no-shadow --no-cancel --item-help\
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "  Mode and IP Information" 20 60 8\
      back "Return to Previous Menu" "Return to Previous Menu" \
      1 "Honeywall Mode" "Honeywall Mode (currently only \"bridge\"" \
      2 "Honeypot IP Address" "Enter the IP address of the honeypot(s)." \
      3 "External Bridge Interface" "Physical external interface of the gateway. By default, eth0."\
      4 "Internal Bridge Interface" "Physical internal interface of the gateway. By default, eth1. "\
      5 "LAN Broadcast Address" "Broadcast address of the LAN honeypots reside upon." \
      6 "LAN CIDR Prefix" "LAN net prefix." )

else

   _res=$(dialog --stdout --no-shadow --no-cancel --item-help\
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "  Mode and IP Information" 20 60 8\
      save "Commit Changes and Return to Previous Menu" "Commit Changes" \
      cancel "Cancel Changes and Return to Previous Menu" "Cancel Changes" \
      1 "Honeywall Mode" "Honeywall Mode (currently only \"bridge\"" \
      2 "Honeypot IP Address" "Enter the IP address of the honeypot(s)." \
      3 "External Bridge Interface" "Physical external interface of the gateway. By default, eth0."\
      4 "Internal Bridge Interface" "Physical internal interface of the gateway. By default, eth1. "\
      5 "LAN Broadcast Address" "Broadcast address of the LAN honeypots reside upon." \
      6 "LAN CIDR Prefix" "LAN net prefix." )

fi


   case ${_res} in
  1) 
      tmp=$(dialog --stdout --no-shadow \
              --backtitle "$(hw_backtitle)" \
              --title "Honeywall Mode"  --clear \
              --msgbox "Only Bridge mode is currently supported..." 5 50)

      if [ "$?" -eq 1 ]; then
         exit 0
      fi
      ;;

   2)
      tmp=$(dialog --stdout --no-shadow \
              --backtitle "$(hw_backtitle)" \
              --title "Honeypot IP Address"  --clear \
              --inputbox " Enter the IP Address(es) of your Honeypot(s)" 10 55 "${HwHPOT_PUBLIC_IP}")

      if [ "$?" -eq 0 ]; then
	   if [ "$tmp" != "$HwHPOT_PUBLIC_IP" ]; then
                 changed=yes
		 HwHPOT_PUBLIC_IP="$tmp"
           fi
      fi
      ;;


   3)
      tmp=$(dialog --stdout --no-shadow \
              --backtitle "$(hw_backtitle)" \
              --title "External Bridge Interface"  --clear \
              --inputbox " Enter the name of the External Bridge Interface" 10 45 "${HwINET_IFACE}")

      if [ "$?" -eq 0 ]; then
         if [ $(hw_isvalidnic $tmp) -eq 0 ]; then
             dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Invalid NIC" \
                --msgbox "\"${tmp}\" is not a valid network interface.  Specify another device, or check the Status menu for a list of valid devices." 15 45 
         else
           # Don't change this variable yet, since this would affect
           # restarting the bridge.
	   if [ "$tmp" != "$HwINET_IFACE" ]; then
            reset_bridge=yes
            changed=yes
            HwINET_IFACE="$tmp"
           fi
         fi
      fi
      ;;
   
   4)
      tmp=$(dialog --stdout --no-shadow \
              --backtitle "$(hw_backtitle)" \
              --title "Internal Bridge Interface"  --clear \
              --inputbox " Enter the name of the Internal Bridge Interface" 10 45 "${HwLAN_IFACE}")

      if [ "$?" -eq 0 ]; then
         if [ $(hw_isvalidnic $tmp) -eq 0 ]; then
             dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "Invalid NIC" \
                --msgbox "\"${tmp}\" is not a valid network interface.  Specify another device, or check the Status menu for a list of valid devices." 15 45 
         else
           # Don't change this variable yet, since this would affect
           # restarting the bridge.
	   if [ "$tmp" != "$HwLAN_IFACE" ]; then
            reset_bridge=yes
            changed=yes
            HwLAN_IFACE="$tmp"
           fi
         fi
      fi
      ;;
  
   5)
      tmp=$(dialog --stdout --no-shadow \
              --backtitle "$(hw_backtitle)" \
              --title "LAN Broadcast Address"  --clear \
              --inputbox " Enter the Broadcast address of the LAN" 10 45 "${HwLAN_BCAST_ADDRESS}")

      if [ "$?" -eq 0 ]; then
	   if [ "$tmp" != "$HwLAN_BCAST_ADDRESS" ]; then
		 changed=yes
		 HwLAN_BCAST_ADDRESS="$tmp"
	   fi
      fi
      ;;

    6)
       tmp=$(dialog --stdout --no-shadow \
	        --backtitle "$(hw_backtitle)" \
                --title "Local IP network "  --clear \
                --inputbox " CIDR Notation net prefix.  EX. 10.0.1.0/24 " 10 45 "${HwLAN_IP_RANGE}")
       
       if [ "$?" -eq 0 ]; then
	   if [ "$tmp" != "$HwLAN_IP_RANGE" ]; then
		  changed=yes
		  HwLAN_IP_RANGE="$tmp"
	   fi
       fi
      ;;

   save)
      if [ "$reset_bridge" != "no" ]; then
          
      tmp=$(dialog --stdout --no-shadow \
              --backtitle "$(hw_backtitle)" \
              --title "Restarting Services"  --clear \
              --msgbox "Press a key to restart services... This may take awhile..." 5 65)
          # Stop the bridge, using the old settings first.
          /etc/rc.d/init.d/hwdaemons stop
          # Make the variables take effect.
          hw_set HwINET_IFACE "$HwINET_IFACE"
          hw_set HwLAN_IFACE "$HwLAN_IFACE"
	  hw_set HwLAN_IP_RANGE "$HwLAN_IP_RANGE"
          hw_set HwLAN_BCAST_ADDRESS "$HwLAN_BCAST_ADDRESS"
          hw_set HwHPOT_PUBLIC_IP "$HwHPOT_PUBLIC_IP"
          # Now start it using the new settings.
          /etc/rc.d/init.d/hwdaemons start
      else 
	  hw_set HwLAN_IP_RANGE "$HwLAN_IP_RANGE"
	  hw_set HwLAN_BCAST_ADDRESS "$HwLAN_BCAST_ADDRESS"
	  hw_set HwHPOT_PUBLIC_IP "$HwHPOT_PUBLIC_IP"
	  # Now reset everything else that needs resetting.
	  hwctl -r
      fi
      exit 0
      ;;

   back)
      # Go back doing nothing
      exit 0
      ;;
   cancel)
      # Cancel changes.. Go back doing nothing
      exit 0
      ;;

   esac
done

# NOTREACHED (but exit with a value anyway for good programming form.)
exit 0
