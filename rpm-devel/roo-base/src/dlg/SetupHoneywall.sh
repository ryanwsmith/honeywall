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
# $Id: SetupHoneywall.sh 4543 2006-10-16 16:22:18Z esammons $
#
# PURPOSE: To walk the user through all necessary honeywall configuration
#          variables in order to make it easier to deploy a honeywall.

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

PATH=${PATH}:/usr/bin:/sbin:/bin

dialog --stdout --no-shadow --cancel-label "Return to main menu"\
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox "   Welcome to the initial setup of your Honeywall \
                Gateway.  This menu will now take you through \
                a series of questions that will help build and \
                configure your Honeywall gateway.  It is assumed \
                you have read and understand all the concepts \
                discussed in the paper \"Know Your Enemy: Honeynets\". \
                Once you are done with the initial setup, all the \
                options will be saved to the configuration file. \
                We will begin by asking you Mode and IP Information. \
                This will help us build your gateway." 18 50 

if [ $? -eq 1 ]; then
   exit 0
fi

# If the honeywall is not yet configured, make sure that we
# create a set of defaults that can be used to prime the interview
# scripts.  The user can change these defaults by replacing
# /etc/honeywall.conf using the worm hole.

if [ $(hw_isconfigured) -eq 0 ]; then
	if [ ! -f /etc/honeywall.conf ]; then
		echo "$0: no /etc/honeywall.conf file found. Man, are you hosed!"
		exit 1
	else
		loadvars /etc/honeywall.conf
	fi
fi

# Set variables from existing config.
hw_setvars


#Mode configuration

tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Honeypot IP Address"  --clear \
   --inputbox " Enter the IP Address(es) of your Honeypot(s)" 10 55 "${HwHPOT_PUBLIC_IP}")

if [ $? -eq 0 ]; then
   hw_set HwHPOT_PUBLIC_IP "${tmp}"
fi

# Needed for hflow
tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Local Honeynet Network"  --clear \
   --inputbox " Enter the Honeynet Network CIDR eg. 10.0.1.0/24 " 10 55 "${HwLAN_IP_RANGE}")

if [ $? -eq 0 ]; then
   hw_set HwLAN_IP_RANGE "${tmp}"
fi

#end Mode conf

#First we'll try to bring up the external bridge interface.
ifconfig "${HwINET_IFACE}" up
ifconfig "${HwINET_IFACE}" | grep UP &>/dev/null

if [ $? -eq 0 ]; then
   INET_IFACE_STATUS="found"
   #Let's go ahead and bring it back down
   ifconfig "${HwINET_IFACE}" down
else
   INET_IFACE_STATUS="!found"
fi

#Now bring up the internal bridge interface
ifconfig "${HwLAN_IFACE}" up
ifconfig "${HwLAN_IFACE}" | grep UP &>/dev/null

if [ $? -eq 0 ]; then
   LAN_IFACE_STATUS="found"
   
   #Let's go ahead and bring it back down
   ifconfig "${HwLAN_IFACE}" down
else
   LAN_IFACE_STATUS="!found"
fi

hw_setvars
if [ "${INET_IFACE_STATUS}" = "found" ] &&
   [ "${LAN_IFACE_STATUS}" = "found" ]; then
   dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox " Found ${HwINET_IFACE} and ${HwLAN_IFACE}!" 5 45

elif [ "${INET_IFACE_STATUS}" = "found" ] &&
     [ "${LAN_IFACE_STATUS}" = "!found" ]; then
   dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox " Found ${HwINET_IFACE} but not ${HwLAN_IFACE}!" 5 45
   exit 1

elif [ "${INET_IFACE_STATUS}" = "!found" ] &&
     [ "${LAN_IFACE_STATUS}" = "found" ]; then
   dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox " Found ${HwLAN_IFACE} but not ${HwINET_IFACE}!" 5 45
   exit 1

else
   dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox " Could not find either Interface on system interface!!!" 5 45
   exit 1
fi
   
tmp="${HwLAN_BCAST_ADDRESS}"
tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "LAN Broadcast Address"  --clear \
   --inputbox " Enter the Broadcast address of the Honeynet" 10 55 "${HwLAN_BCAST_ADDRESS}")

if [ $? -eq 0 ]; then
   hw_set HwLAN_BCAST_ADDRESS "${tmp}"
fi

dialog --stdout --no-shadow --cancel-label "Return to main menu"\
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox "   You have just finished the first section of configuring \
                your Honeywall gateway, we will now move onto the second \
                section.  Here you will configure all the remote management \
                issues, including SSH." 10 50

if [ $? -eq 1 ]; then
   exit 1
fi

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Management Interface"  --clear \
   --yesno " Would you like to configure a management interface?" 10 60

# Now bring up the management interface.
if [ $? -eq 0 ]; then
   tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "Management Interface"  --clear \
      --inputbox " Enter the NIC to use for the management interface" 10 55 "${HwMANAGE_IFACE}")

   if [ $? -eq 0 ]; then
      HwMANAGE_IFACE="${tmp}"
      hw_set HwMANAGE_IFACE "${tmp}"
   fi

   #Let's bring it up for testing.
   #ifconfig ${HwMANAGE_IFACE} up
   #ifconfig ${HwMANAGE_IFACE} | grep UP
 
   if [ $? -eq 0 ]; then
      dialog --stdout --no-shadow \
         --backtitle "$(hw_backtitle)" \
         --title "Configure Management Interface"  --clear \
         --msgbox "Looks like ${HwMANAGE_IFACE} is up!" 5 45
         hw_set HwMANAGE_IFACE eth2
  else
      dialog --stdout --no-shadow \
         --backtitle "$(hw_backtitle)" \
         --title "Configure Management Interface"  --clear \
         --msgbox "Could not find ${HwMANAGE_IFACE}.  Try loading the driver manually." 10 55
       break
       #exit Need to do something else here
   fi

   tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "Management Interface IP Address"  --clear \
      --inputbox " Enter the IP address of the management interface" 10 55 "${HwMANAGE_IP}")

   if [ $? -eq 0 ]; then
      HwMANAGE_IP="${tmp}"
      hw_set HwMANAGE_IP "${tmp}"
   fi

   tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "Management Interface Network Mask"  --clear \
      --inputbox " Enter the Network Mask of the management interface" 10 55 "${HwMANAGE_NETMASK}")

   if [ $? -eq 0 ]; then
      hw_set HwMANAGE_NETMASK "${tmp}"
   fi

   tmp=$(dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Configure Management Interface"  --clear \
      --inputbox "Enter a default gateway for ${HwMANAGE_IP}." 10 55 "${HwMANAGE_GATEWAY}")

   if [ $? -eq 0 ]; then
      hw_set HwMANAGE_GATEWAY "${tmp}"
   fi

########################################################################

  HOSTNAME_VRFY=0
  while [ "${HOSTNAME_VRFY}" -eq 0 ]; do
    tmpHost=$(/bin/hostname --short)
    tmp=$(dialog --stdout --no-shadow \
       --backtitle "$(hw_backtitle)" \
       --title "Configure Management Interface"  --clear \
       --inputbox "Enter the system Hostname (Host only part of FQDN)\n For example, the Hostname of the FQDN \"myhost.some.domain\" is \"myhost\"." 10 55 "${tmpHost}") 

    if [ $? -eq 0 ]; then
       if [ "x${tmp}" == "x" ]; then
  	  dialog --stdout --no-shadow --cancel-label "Return to main menu"\
       	  --backtitle "$(hw_backtitle)" \
          --title "Configure Management Interface"  --clear \
      	  --msgbox "\n   Hostname cannot be null." 10 55 
	  if [ $? -eq 1 ]; then
	     exit 0
	  fi
       elif [ "$(echo "${tmp}" | egrep -c "[\.|_]")" -gt 0 ]; then
	  dialog --stdout --no-shadow --cancel-label "Return to main menu"\
      	  --backtitle "$(hw_backtitle)" \
          --title "Configure Management Interface"  --clear \
      	  --msgbox "\n   Hostname cannot contian \".\" or \"_\" ." 10 55 
	  if [ $? -eq 1 ]; then
	     exit 0
	  fi
       else
       hw_set HwHOSTNAME "${tmp}"
       HOSTNAME_VRFY=1
       fi
    elif [ $? -eq 1 ]; then
	exit 1
    fi
  done
############################################################################

  DOMAIN_VRFY=0
  while [ "${DOMAIN_VRFY}" -eq 0 ]; do
    tmpDom=$(/bin/hostname --domain)

   tmp=$(dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Configure Management Interface"  --clear \
      --inputbox "Enter the DNS domain if you have one (localhost if not).  The Domain will be appended to the Hostname to form the fully qualified domain name (FQDN)." 10 55 "${tmpDom}") 

    if [ $? -eq 0 ]; then
       if [ "x${tmp}" == "x" ]; then
  	  dialog --stdout --no-shadow --cancel-label "Return to main menu"\
       	  --backtitle "$(hw_backtitle)" \
          --title "Configure Management Interface"  --clear \
      	  --msgbox "\n   Domain cannot be null." 10 55 
	  if [ $? -eq 1 ]; then
	     exit 0
	  fi
       else
       hw_set HwDOMAIN "${tmp}"
       DOMAIN_VRFY=1
       fi
    elif [ $? -eq 1 ]; then
	exit 1
    fi
  done

  hw_sethostname "$(hw_get HwHOSTNAME)"

##############################################################################

   tmp=$(dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Configure Management Interface"  --clear \
      --inputbox "Enter DNS Server IPs (Space delimited) for honeywall gateway use" 10 55 "${HwMANAGE_DNS}")

   if [ $? -eq 0 ]; then
      hw_set HwMANAGE_DNS "${tmp}"
      #call script to set nameservers
      /dlg/config/dns2resolv.sh
   fi


   dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Configure Management Interface"  --clear \
      --yesno "Would you like to activate this interface?" 5 55

   if [ $? -eq 0 ]; then
      #Let's bring this interface up
      _bcast_addr=$(/bin/ipcalc "${HwMANAGE_IP}" "${HwMANAGE_NETMASK}" -b | cut -d "=" -f 2)

      ifconfig "${HwMANAGE_IFACE}" "${HwMANAGE_IP}" netmask "${HwMANAGE_NETMASK}" broadcast \
      "${_bcast_addr}" up
      ifconfig "${HwMANAGE_IFACE}" | grep "${HwMANAGE_IP}"

      route add default gw ${HwMANAGE_GATEWAY}
   fi
   
   dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Configure Management Interface"  --clear \
      --yesno "Would you like this interface to start on next boot?" 7 55
   if [ $? -eq 0 ]; then
      hw_set HwMANAGE_STARTUP yes
   else
      hw_set HwMANAGE_STARTUP no
   fi

   dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Configure SSH"  --clear \
      --yesno "Would you like to configure SSH?" 5 45

   if [ $? -eq 0 ]; then
      dialog --stdout --no-shadow \
                --backtitle "$(hw_backtitle)" \
                --title "SSHD permit remote root login" --defaultno --clear \
                --yesno "Allow root to login remotely?  It is not necessary to allow root to login remotely." 10 55

      if [ $? -eq 0 ]; then
         hw_set HwSSHD_REMOTE_ROOT_LOGIN yes
      else
         hw_set HwSSHD_REMOTE_ROOT_LOGIN no

         #NEWUSER=$(/usr/bin/dialog --stdout --no-shadow \
         #       --backtitle "$(hw_backtitle)" \
         #       --title "Adding a new user"  --clear \
         #       --inputbox "We will need to add a user.  Enter the username" 10 55) 
      
         #useradd -m ${NEWUSER}
         #/dlg/admin/Password.sh ${NEWUSER}
         #/dlg/admin/AddUser.sh
      fi
	/dlg/config/hw_build_ssh_config.sh
      
   fi

   #Let's change the root password. 
   /dlg/admin/Password.sh
   #Let's change the roo's password too
   /dlg/admin/Password.sh roo

   tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "Management Interface Allowed Inbound"  --clear \
      --inputbox " Enter a space delimited list of TCP ports allowed into the management interface. NOTE: Do NOT include the SSHD port.  It will be added automatically." \
      10 55 "${HwALLOWED_TCP_IN}")

   if [ $? -eq 0 ]; then
      hw_set HwALLOWED_TCP_IN "${tmp}"
   fi

   tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "Manager"  --clear \
      --inputbox " Enter a space delimited list of IP addresses that can access the management\
      interface (\"any\" for any IP address)" 10 55 "${HwMANAGER}")

   if [ $? -eq 0 ]; then
      hw_set HwMANAGER "${tmp}"
   fi

   # Walleye

   dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "Enable Walleye Web GUI"  --clear \
      --yesno " Would you like to enable the web interface for Data Analysis and Management?" 10 55

   if [ $? -eq 0 ]; then
       hw_set HwWALLEYE yes
   else
       hw_set HwWALLEYE no
   fi

   dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "Firewall Restrictions"  --clear \
      --yesno " Would you like to restrict firewall outbound communications?" 10 55

   if [ $? -eq 0 ]; then
      hw_set HwRESTRICT yes

      tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
         --backtitle "$(hw_backtitle)" \
         --title "TCP Allowed OUT"  --clear \
         --inputbox " Enter a space delimited list of TCP Ports allowed out" 10 55 \
         "${HwALLOWED_TCP_OUT}")

      if [ $? -eq 0 ]; then
         hw_set HwALLOWED_TCP_OUT "${tmp}"
      fi

      tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
         --backtitle "$(hw_backtitle)" \
         --title "UDP Allowed OUT"  --clear \
         --inputbox " Enter a space delimited list of UDP Ports allowed out" 10 55 \
         "${HwALLOWED_UDP_OUT}")

      if [ $? -eq 0 ]; then
         hw_set HwALLOWED_UDP_OUT "${tmp}"
      fi
   else
      hw_set HwRESTRICT no
   fi   # end of Firewall Restriction

else
   hw_set HwMANAGE_STARTUP no
fi # end of Management Configuration

dialog --stdout --no-shadow --cancel-label "Return to main menu"\
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox "   You have just finished the second section of configuring \
                your Honeywall gateway, we will now move onto the third \
                section.  Here you will configure all the outbound \
                control limits." 10 50

if [ $? -eq 1 ]; then
   exit 0
fi

# Connection Limiting.

tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Connection Limiting Configuration"  --clear \
   --inputbox " What scale would you like to use? (second, minute, hour, day, month)" 10 55 "${HwSCALE}")

if [ $? -eq 0 ]; then
   hw_set HwSCALE "${tmp}"
fi

tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Connection Limiting Configuration"  --clear \
   --inputbox " Enter TCP Limit" 10 55 "${HwTCPRATE}")

if [ $? -eq 0 ]; then
   hw_set HwTCPRATE "${tmp}"
fi

tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Connection Limiting Configuration"  --clear \
   --inputbox " Enter UDP Limit" 10 55 "${HwUDPRATE}")

if [ $? -eq 0 ]; then
   hw_set HwUDPRATE "${tmp}"
fi

tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Connection Limiting Configuration"  --clear \
   --inputbox " Enter ICMP Limit" 10 55 "${HwICMPRATE}")

if [ $? -eq 0 ]; then
   hw_set HwICMPRATE "${tmp}"
fi

tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Connection Limiting Configuration"  --clear \
   --inputbox " Enter Limit for all other protocols" 10 55 "${HwOTHERRATE}")
         
if [ $? -eq 0 ]; then
   hw_set HwOTHERRATE "${tmp}"
fi

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Queue Configuration"  --clear \
   --yesno " Would you like to prepare the firewall to send packets to snort_inline?" 10 55

if [ $? -eq 0 ]; then
    hw_set HwQUEUE yes
else
   hw_set HwQUEUE no
fi


# Blacklist
tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Black list (Drop/no log)"  --clear \
   --inputbox " Name of file containing the blacklist (IP addresses and CIDR blocks to be dropped without logging)" 12 45 "${HwFWBLACK}")

if [ $? -eq 0 ]; then
   hw_set HwFWBLACK "${tmp}"
fi

# Whitelist
tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Whitelist"  --clear \
   --inputbox " Name of file containing the whitelist (IP addresses and CIDR blocks to be allowed without logging)" 12 45 "${HwFWWHITE}")

if [ $? -eq 0 ]; then
   hw_set HwFWWHITE "${tmp}"
fi

# Enable black & white lists.  (Note that these should be separated
# to allow independant control, rather than both or none.)

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Enable Black list and White list filtering" --defaultno --clear \
   --yesno " Would you like to enable Black list and White list filtering?" 10 55

if [ $? -eq 0 ]; then
    hw_set HwBWLIST_ENABLE yes
else
    hw_set HwBWLIST_ENABLE no
fi

# Disable HwBPF_DISABLE which should be on by default

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Disable \"Strict\" Capture Filtering" --defaultno --clear \
   --yesno " Would you like to disable \"Strict\" Capture filtering?" 10 55

if [ $? -eq 0 ]; then
    hw_set HwBPF_DISABLE yes
else
    hw_set HwBPF_DISABLE no
fi

# Fencelist
tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Fencelist"  --clear \
   --inputbox " Name of file containing the fencelist (IP addresses and CIDR blocks to be protected from any honeypot getting access to.)" 12 45 "${HwFWFENCE}")

if [ $? -eq 0 ]; then
   hw_set HwFWFENCE "${tmp}"
fi

# Enable fencelist.

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Enable Fence list filtering" --defaultno --clear \
   --yesno " Would you like to enable Fence list filtering?" 10 55

if [ $? -eq 0 ]; then
    hw_set HwFENCELIST_ENABLE yes
else
    hw_set HwFENCELIST_ENABLE no
fi

# Roach Motel mode

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Enable \"Roach motel\" mode"  --defaultno --clear \
   --yesno " Would you like to enable \"Roach motel\" mode blocking? (Disallowing ANY traffic outbound from honeypots.)" 12 45

if [ $? -eq 0 ]; then
    hw_set HwROACHMOTEL_ENABLE yes
else
    hw_set HwROACHMOTEL_ENABLE no
fi


dialog --stdout --no-shadow --cancel-label "Return to main menu"\
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox "   You have just finished the third section of configuring \
                your Honeywall gateway, we will now move onto the fourth \
                section.  Here you will configure all the DNS \
                activity of your honeypots." 10 50
                                                                                
if [ $? -eq 1 ]; then
   exit 0
fi

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "DNS Configuration"  --clear \
   --yesno " Would you like to enable your honeypots within the Honeynet unlimited DNS access?" 10 55

if [ $? -eq 0 ]; then
   dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "DNS Configuration"  --clear \
      --yesno " Would you like to restrict which Honeypot has unlimited access to external \
      DNS servers?" 10 55

   if [ $? -eq 0 ]; then
      tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
               --backtitle "$(hw_backtitle)" \
               --title "DNS Configuration"  --clear \
               --inputbox " Enter a space delimited list of Honeypot(s) that can access external DNS \
               servers?" 10 55 "${HwDNS_HOST}")

      if [ $? -eq 0 ]; then
         hw_set HwDNS_HOST "${tmp}"
      fi

   else
         hw_set HwDNS_HOST "$HwHPOT_PUBLIC_IP"
   fi

   dialog --stdout --no-shadow --cancel-label "Return to main menu" \
      --backtitle "$(hw_backtitle)" \
      --title "DNS Configuration"  --clear \
      --yesno " Would you like to restrict which DNS server can be used for unlimited access?" 10 55

   if [ $? -eq 0 ]; then
      tmp=$(dialog --stdout --no-shadow --cancel-label "Return to main menu" \
               --backtitle "$(hw_backtitle)" \
               --title "DNS Configuration"  --clear \
               --inputbox " Enter a space delimited list of DNS Servers for\
                    honeypot use" 10 55 "${HwDNS_SVRS}")

      if [ $? -eq 0 ]; then
         hw_set HwDNS_SVRS "${tmp}"
      fi

   else
      hw_set HwDNS_SVRS ""
   fi

else 
   hw_set HwDNS_SVRS ""

      hw_set HwDNS_HOST "$HwHPOT_PUBLIC_IP"
fi # end of unlimited DNS conf
hw_setvars

dialog --stdout --no-shadow --cancel-label "Return to main menu"\
      --backtitle "$(hw_backtitle)" \
      --title "Initial Setup"  --clear \
      --msgbox "   You have just finished the fourth section of configuring\
                your Honeywall gateway, we will now move onto the fifth\
                and final section.  Here you will configure the remote\
                alerting mechanism." 10 50

if [ $? -eq 1 ]; then
   exit 0
fi

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Alert Configuration"  --clear \
   --yesno " Would you like to enable Email Alerts?" 5 45

if [ $? -eq 0 ]; then
    #Make sure swatch is not running.
    /etc/init.d/swatch.sh stop &>/dev/null

    #Get email address from user.
    tmp=$(/usr/bin/dialog --stdout --no-shadow \
       --backtitle "$(hw_backtitle)" \
       --title "Configure Alerting" \
       --inputbox "Enter an e-mail address to receive alerts.\
                  Email alerts are only generated for outbound\
                  activity.\n\nNOTE: If enabling alerting, make\
                  sure you allow TCP 25 outbound, and the mail\
                  server/relay accepts mail from this system."\
                  17 50 "${HwALERT_EMAIL}")
                                                                              
    if [ $? -eq 1 ]; then
       exit 1
    else
       hw_set HwALERT_EMAIL "${tmp}"
    fi

    /usr/bin/dialog --stdout --no-shadow \
        --backtitle "$(hw_backtitle)" \
        --title "Configure Alerting" \
        --yesno "Would you like alerting to start automatically at boot?" 5 60
                                                                                
    if [ $? -eq 1 ]; then
        hw_set HwALERT no
        exit 0
    else
        hw_set HwALERT yes
    fi
                                                                                
    #Run swatch.
    /etc/init.d/swatch.sh start
fi

/dlg/config/SebekConfig.sh init

dialog --stdout --no-shadow --cancel-label "Return to main menu" \
   --backtitle "$(hw_backtitle)" \
   --title "Initial Setup"  --clear \
   --msgbox "\nYou have just finished the initial Honeywall setup!\nWe will now apply changes and return to main menu. It is normal to see some errors during the initial process restart that follows.\n\nEnjoy! " 10 60
hw_set HwHONEYWALL_RUN yes

/etc/rc.d/init.d/hwdaemons restart

exit 0
