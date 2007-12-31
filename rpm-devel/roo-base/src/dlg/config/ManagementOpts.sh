#!/bin/bash
#
# $Id: ManagementOpts.sh 4543 2006-10-16 16:22:18Z esammons $
#
# PURPOSE: Used to configure the management variables used by the firewall to
#          restrict the management interface.
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

changed=no

hw_setvars

while true 
do

if [ "$changed" == "no" ]; then

   _res=$(dialog --stdout --no-shadow --no-cancel --item-help \
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "          Management Variables" 20 50 13 \
      back "Return to Previous Menu" "Return to Previous Menu" \
      1 "Management IP" "IP address of the management interface." \
      2 "Management Netmask" "Netmask of IP interface."\
      3 "Management Gateway" "Default Gateway for interface." \
      4 "Management Hostname" "System Hostname for honeywall."\
      5 "Management Domain" "DNS Domain name for honeywall." \
      6 "Management DNS Servers" "DNS Servers used by Management Interface." \
      7 "Manager" "Space deliminited list of IPs or networks that can access this interface."\
      8 "Allowed Inbound TCP" "What inbound TCP connections are allowed."\
      9 "Restrict Honeywall Outbound Traffic" "Allow the gateway to initiate any outbound traffic?"\
      10 "Honeywall Allowed Outbound TCP" "What TCP traffic is allowed outbound."\
      11 "Honeywall Allowed Outbound UDP" "What UDP traffic is allowed outbound."\
      12 "Walleye" "Run web based UI" )

else
   _res=$(dialog --stdout --no-shadow --no-cancel --item-help \
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "          Management Variables" 22 50 14 \
      save "Commit Changes and Return to Previous Menu" "Commit Changes" \
      cancel "Cancel Changes and Return to Previous Menu" "Cancel Changes" \
      1 "Management IP" "IP address of the management interface." \
      2 "Management Netmask" "Netmask of IP interface."\
      3 "Management Gateway" "Default Gateway for interface." \
      4 "Management Hostname" "System Hostname for honeywall."\
      5 "Management Domain" "DNS Domain name for honeywall." \
      6 "Management DNS Servers" "DNS Servers used by Management Interface." \
      7 "Manager" "Space deliminited list of IPs or networks that can access this interface."\
      8 "Allowed Inbound TCP" "What inbound TCP connections are allowed."\
      9 "Restrict Honeywall Outbound Traffic" "Allow the gateway to initiate any outbound traffic?"\
      10 "Honeywall Allowed Outbound TCP" "What TCP traffic is allowed outbound."\
      11 "Honeywall Allowed Outbound UDP" "What UDP traffic is allowed outbound."\
      12 "Walleye" "Run web based UI" )

fi

   case ${_res} in

      1)
         old="$HwMANAGE_IP"
         new=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Management Interface IP Address"  --clear \
            --inputbox " Enter the IP address of the management interface" 10 45 "${old}")

         if [ "$?" -eq 0 ]; then
           if [ "$old" != "$new" ]; then
              changed=yes
              HwMANAGE_IP="${new}"
           fi
         fi
         ;;

      2) 
         old="$HwMANAGE_NETMASK"
         new=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Management Interface Network Mask"  --clear \
            --inputbox " Enter the Network Mask of the management interface" 10 45 "${old}")

         if [ "$?" -eq 0 ]; then
           if [ "$old" != "$new" ]; then
              changed=yes
              HwMANAGE_NETMASK="${new}"
           fi
         fi
         ;;

      3)
         old="$HwMANAGE_GATEWAY"
         new=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Management Default Gateway"  --clear \
            --inputbox " Enter the IP address of the management default gateway." 10 45 "${old}")

         if [ "$?" -eq 0 ]; then
           if [ "$old" != "$new" ]; then
              changed=yes
              HwMANAGE_GATEWAY="${new}"
           fi
         fi
         ;;

##########################################################################
      4)
	HOSTNAME_VRFY=0
	while [ "${HOSTNAME_VRFY}" -eq 0 ]; do
	   old="${HwHOSTNAME}"
	   new=$(dialog --stdout --no-shadow \
	     --backtitle "$(hw_backtitle)" \
             --title "Management Hostname"  --clear \
             --inputbox "Enter the system Hostname (Host only part of FQDN)\n For example, the Hostname of the FQDN \"myhost.some.domain\" is \"myhost\"." 10 55 "${HwHOSTNAME}") 

    	   if [ $? -eq 0 ]; then
             if [ "x${new}" == "x" ]; then
  	        dialog --stdout --no-shadow --cancel-label "Return to main menu"\
       	        --backtitle "$(hw_backtitle)" \
                --title "Management Hostname"  --clear \
      	        --msgbox "\n   Hostname cannot be null." 10 55 
	        if [ $? -eq 1 ]; then
                   HOSTNAME_VRFY=1
	        fi
             elif [ "$(echo "${new}" | egrep -c "[\.|_]")" -gt 0 ]; then
	          dialog --stdout --no-shadow --cancel-label "Return to main menu"\
      	           --backtitle "$(hw_backtitle)" \
                   --title "Management Hostname"  --clear \
      	           --msgbox "\n   Hostname cannot contian \".\" or \"_\" ." 10 55 
	        if [ $? -eq 1 ]; then
                   HOSTNAME_VRFY=1
	        fi
             else
                if [ "$old" != "$new" ]; then
                   changed=yes
       	           HwHOSTNAME="${new}"
	        fi
                HOSTNAME_VRFY=1
              fi
           elif [ $? -eq 1 ]; then
                HOSTNAME_VRFY=1
            fi
        done
	;;
############################################################################
     5)
	DOMAIN_VRFY=0
  	while [ "${DOMAIN_VRFY}" -eq 0 ]; do
	   old="${HwDOMAIN}"
   	   new=$(dialog --stdout --no-shadow \
      	      --backtitle "$(hw_backtitle)" \
              --title "Management Domain Name"  --clear \
              --inputbox "Enter the DNS domain if you have one (localhost if not).  The DNS domain will be appended to the Hostname to form the fully qualified domain name (FQDN)." 10 55 "${HwDOMAIN}") 

    	   if [ $? -eq 0 ]; then
              if [ "x${new}" == "x" ]; then
  	         dialog --stdout --no-shadow --cancel-label "Return to main menu"\
       	           --backtitle "$(hw_backtitle)" \
                   --title "Management Domain Name"  --clear \
      	           --msgbox "\n   Domain cannot be null." 10 55 
	  	 if [ $? -eq 1 ]; then
                    DOMAIN_VRFY=1
	         fi
              else
                 if [ "$old" != "$new" ]; then
                    changed=yes
                    HwDOMAIN="${new}"
		 fi
                 DOMAIN_VRFY=1
              fi
           elif [ $? -eq 1 ]; then
              DOMAIN_VRFY=1
           fi
        done
	;;

##############################################################################

      6) 
         old="$HwMANAGE_DNS"
         new=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Management DNS Servers"  --clear \
            --inputbox " Enter a space delimited list of DNS Servers to be used by the Managment Interface" 10 45 "${old}")

         if [ "$?" -eq 0 ]; then
           if [ "$old" != "$new" ]; then
              changed=yes
              HwMANAGE_DNS="${new}"
           fi
         fi
         ;;

      7)
         old="$HwMANAGER"
         new=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Manager"  --clear \
            --inputbox " Enter a space delimited list of IP addresses that can access the management interface (\"any\" for any IP address)" 10 45 "${old}")

         if [ "$?" -eq 0 ]; then
           if [ "$old" != "$new" ]; then
              changed=yes
              HwMANAGER="${new}"
           fi
         fi
         ;;

      8)
         old="$HwALLOWED_TCP_IN"
         new=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Management Interface Allowed Inbound"  --clear \
            --inputbox " Enter a space delimited list of TCP ports allowed into the management interface.  NOTE: Do NOT include the SSHD port.  It will automatically be added." 10 45 "${old}")

         if [ "$?" -eq 0 ]; then
           if [ "$old" != "$new" ]; then
              changed=yes
              HwALLOWED_TCP_IN="${new}"
           fi
         fi
         ;;

      9)
         dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Firewall Restrictions"  --clear \
            --yesno " Would you like to restrict firewall outbound communications?" 10 45 

         if [ "$?" -eq 0 ]; then
            changed=yes
            HwRESTRICT="yes"
         else
            changed=yes
            HwRESTRICT="no"
         fi
         ;;

      10)
         old="$HwALLOWED_TCP_OUT"
         new=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "TCP Allowed OUT"  --clear \
            --inputbox " Enter a space delimited list of TCP Ports allowed out" 10 45 "${old}")
            
         if [ "$?" -eq 0 ]; then
           if [ "$old" != "$new" ]; then
              changed=yes
              HwALLOWED_TCP_OUT="${new}"
           fi
         fi
         ;;

      11)
         old="$HwALLOWED_UDP_OUT"
         new=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "UDP Allowed OUT"  --clear \
            --inputbox " Enter a space delimited list of UDP Ports allowed out" 10 45 "${old}")
           
         if [ "$?" -eq 0 ]; then
           if [ "$old" != "$new" ]; then
              changed=yes
              HwALLOWED_UDP_OUT="${new}"
           fi
         fi
         ;;

      12)
         dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Walleye User Interface"  --clear \
            --yesno " Would you like to run the Walleye web interface? " 10 45

         if [ "$?" -eq 0 ]; then
            changed=yes
            HwWALLEYE="yes"
         else
            changed=yes
            HwWALLEYE="no"
	 fi
         ;;

      save)
         
	 hw_set "HwMANAGE_IP" "$HwMANAGE_IP"
         hw_set "HwMANAGE_NETMASK" "$HwMANAGE_NETMASK"
         hw_set "HwMANAGE_GATEWAY" "$HwMANAGE_GATEWAY"
	 hw_set "HwHOSTNAME" "${HwHOSTNAME}"
         hw_set "HwDOMAIN" "$HwDOMAIN"
         hw_set "HwMANAGE_DNS" "$HwMANAGE_DNS"
         hw_set "HwMANAGER" "$HwMANAGER"
         hw_set "HwALLOWED_TCP_IN" "$HwALLOWED_TCP_IN"
         hw_set "HwRESTRICT" "$HwRESTRICT"
         hw_set "HwALLOWED_TCP_OUT" "$HwALLOWED_TCP_OUT"
         hw_set "HwALLOWED_UDP_OUT" "$HwALLOWED_UDP_OUT"
         hw_set "HwWALLEYE" "$HwWALLEYE"
         hwctl -r
  	 hw_sethostname "$(hw_get HwHOSTNAME)"
         exit 0;
         ;;

      back)
         exit 0;
         ;;

      cancel)
         exit 0;
         ;;

   esac
done

exit 0
