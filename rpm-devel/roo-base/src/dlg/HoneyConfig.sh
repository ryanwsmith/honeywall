#!/bin/bash
#
# $Id: HoneyConfig.sh 4360 2006-09-03 01:58:29Z esammons $
#
# PURPOSE: To allow the user to manage Honeywall configuration.
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


# Must be root to run this
if [ "${UID}" -ne 0 ]; then
        echo ""
        echo "$0: Only \"root\" can run $0"
        echo ""
        exit 1
fi
####################################################################

. /etc/rc.d/init.d/hwfuncs.sub

PATH=/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/bin

function config_floppy {
   mcopy -n a:/honeywall.conf /tmp 2>&1 > /dev/null

   case $? in
   1) 
       # Explain to user that there isn't a config file on
       # floppy.
       dialog --no-shadow \
          --backtitle "$(hw_backtitle)" \
          --title "NO FILE found on floppy."  \
          --defaultno --clear \
          --msgbox "There was no file found on drive.  Please insert \
                    a floppy with a configuration file and try again" 14 30
       ;;
    2) # Explain to user that there is no media in drive
       dialog --no-shadow \
          --backtitle "$(hw_backtitle)" \
          --title "NO MEDIA in the drive."  \
          --defaultno --clear \
          --msgbox "There was no media in drive.  Please insert \
                    a floppy and try again." 14 30
      ;;

    0) # Double check they really want to do this.
       dialog --no-shadow \
          --backtitle "$(hw_backtitle)" \
          --title "WARNING: configuration subsytem will be rebuilt!"\
          --defaultno --clear \
          --yesno "This action will utilize the configuration file found on the floppy to configure your Honeywall.  Are you sure you want to proceed?" 10 60
       if [ $? -eq 0 ]; then
	  # Populate the configuration directory with the
	  # honeywall.conf file
	  if [ -f /tmp/honeywall.conf ]; then
	     cp /tmp/honeywall.conf /etc
	     loadvars < /etc/honeywall.conf
	     #Let's tell it to run the Honeywall on boot and apply changes.
       	     echo 'Honeywall set up from file on floppy.  Applying changes...'
             hw_set "HwHONEYWALL_RUN" "yes"
#             hw_startHoneywall
	     /etc/init.d/hwdaemons restart
	  else
	     dialog --no-shadow \
	        --backtitle "$(hw_backtitle)" \
	        --title "ERROR!" --clear\
	        --msgbox "Could not open honeywall.conf.  Make sure \
	                  it actually exists on the floppy and try \
                          again." 15 45
	  fi
       fi
       ;;
    esac
}

function config_defaults {
   dialog --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "WARNING: configuration subsytem will be rebuilt!"\
      --defaultno --clear \
      --yesno "This action will utilize the default /etc/honeywall.conf configuration file to configure your Honeywall. THIS WILL KILL YOUR SSH SESSION IF YOU ARE LOGGED IN REMOTELY! Are you sure you want to proceed?" 15 60
   if [ $? -eq 0 ]; then
      if [ -f /etc/honeywall.conf.orig ]; then
          cp /etc/honeywall.conf.orig /etc/honeywall.conf
          loadvars < /etc/honeywall.conf
          #Let's tell it to run the Honeywall on boot
          echo 'Honeywall set up from factory defaults.  Applying changes...'
          hw_set "HwHONEYWALL_RUN" "yes"
#          hw_startHoneywall
	  /etc/init.d/hwdaemons restart
       else
          dialog --no-shadow \
              --backtitle "$(hw_backtitle)" \
              --title "ERROR!" --clear\
              --msgbox "Could not find honeywall.conf.orig. Aborting." 15 45
       fi
   fi
}


# If the honeywall is not yet configured at all, simply perform
# and initial configuration and return to the main menu.

if [ $(hw_isconfigured) -eq 0 ]; then
    dialog --stdout --no-shadow --cancel-label "Cancel"\
        --backtitle "$(hw_backtitle)"\
        --defaultno \
        --title "Initial Setup" --clear\
        --yesno "\
LIMITATION OF LIABILITY\n\
=======================\n \
In no event will The Honeynet Project be liable for any damages, \
including loss of data, lost profits, cost of cover, or other special, \
incidental, consequential, direct or indirect damages arising from the \
software or the use thereof, however caused and on any theory of \
liability. This limitation will apply even if The Honeynet Project has \
been advised of the possibility of such damage.  By clicking YES you \
acknowledge that this is a reasonable assumption of risk." 15 70

    if [ "$?" -eq 1 ]; then
        exit 1
    fi

    _opt=$(dialog --stdout --clear --item-help\
             --backtitle "$(hw_backtitle)" \
	     --title "Initial Setup" \
	     --menu "   Initial Setup Method " 10 40 3 \
	       1 "Floppy" "Use honeywall.conf configuration file from floppy"\
	       2 "Defaults" "Setup from factory defaults (/etc/honeywall.conf.orig)"\
	       3 "Interview" "Go through interactive setup")

    case ${_opt} in
    1) # Use the floppy
       config_floppy
       ;;

    2) # Use the original factory defaults.
       config_defaults
       ;;
    3) # Start the interview
       /dlg/SetupHoneywall.sh
       ;;
    esac
    exit 0
fi

# Otherwise, allow individual configuration changes, or allow
# a wholesale reconfiguration.

while true
do
   hw_setvars

   _res=$(dialog --stdout --no-cancel --item-help \
          --backtitle "$(hw_backtitle)" \
          --title "Honeywall Configuration" --clear \
          --menu "Honeywall Configuration Options" 21 45 15 \
          back "Back to main menu" "Return to Main Menu "\
          1 "Mode and IP Information" "Configure the gateway itself."\
          2 "Remote Management" "Configure how the gateway is remotely configured."\
          3 "Connection Limiting" "Limits number of outbound connections from Honeynet."\
          4 "DNS Handling" "Configure how the gateway will handle honeypot DNS requests"\
          5 "Alerting" "Configure Swatch for e-mail alerts."\
          6 "Snort-Inline" "Configure snort_inline"\
          7 "Honeywall Summary" "Configure the Honeywall's traffic summary script" \
          8 "Black and White Lists and BPF" "Configure Black (block/no log) White (allow/no log) lists and BPF Filtering."\
          9 "Outbound Fence List" "Restrict all honeypot access to specified IPs/networks."\
          10 "Roach motel mode" "Configure 'Roach motel' mode (restrict all outbound access from honeypots.)"\
          11 "Sebek" "Configure how the gateway handles sebek packets."\
	  12 "Data Management" "Data Backup and Purge."\
	  13 "Snort Rule Updates" "Configure Snort rule update process"\
          14 "Reconfigure system" "Completely reconfigure the system.")

   case ${_res} in
      back) 
         # Ensure any changes take effect.
         hwctl -r
         exit 0
         ;;
      1) /dlg/config/ModeConfig.sh
         ;;
      2) /dlg/config/ManagementOpts.sh
         ;;
      3) /dlg/config/ConnectionLimit.sh
         ;;
      4) /dlg/config/DNSConfig.sh
         ;;
      5) #Let's make sure swatch is not running
         /etc/init.d/swatch.sh stop &>/dev/null
#EWS_HACK (Be extra sure the PID is gone else start will fail)
	/bin/rm -f /var/run/swatch.pid &> /dev/null

         #Get email address from user.
         ADDRESS=$(dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Configure Alerting" \
            --inputbox "Enter an e-mail address to receive alerts.\
                       Email alerts are only generated for outbound\
                       activity.\n\nNOTE: If enabling alerting, make\
                       sure you allow TCP 25 outbound, and the mail\
                       server/relay accepts mail from this system."\
                       17 50 "${HwALERT_EMAIL}")

         if [ "$?" -eq 1 ]; then
		/dlg/HoneyConfig.sh
         else 
            hw_set "HwALERT_EMAIL" "${ADDRESS}"
         fi

         dialog --stdout --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Configure Alerting" \
            --yesno "Would you like alerting to start automatically at boot?" 10 60

         if [ "$?" -eq 1 ]; then
            hw_set "HwALERT" "no"
            exit 1
         else
            hw_set "HwALERT" "yes"
         fi

         #Run swatch.
#EWS_HACK (Why are we stopping it again???
#         /etc/init.d/swatch.sh stop &> /dev/null
         /etc/init.d/swatch.sh start

        ;;
      6) /dlg/config/SnortinlineConfig.sh
         ;;
      7) /dlg/config/Summary.sh
         ;;
      8) /dlg/config/BlackWhite.sh
         ;;
      9) /dlg/config/FenceList.sh
         ;;
      10) /dlg/config/RoachMotel.sh
         ;;
      11) 
         /dlg/config/SebekConfig.sh
# EWS_HACK for initial setup (was stopping unconfigured 
# services in SebekConfig.sh, now do it here)
	hwctl -r
         ;;
      12)
         /dlg/config/DataManage.sh
         ;;
      13)
	/dlg/config/snortrules_config.sh
	;;
      14)
         dialog --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "WARNING: configuration subsytem will be rebuilt!"\
            --defaultno --clear \
            --yesno "This action will disable your Honeywall, reconfigure it and bring it back up.  THIS WILL KILL YOUR SSH SESSION IF YOU ARE LOGGED IN REMOTELY! Are you sure you want to proceed?" 15 60
         if [ $? -eq 0 ]; then
             hw_stopHoneywall
             _opt=$(dialog --stdout --clear --item-help\
                     --backtitle "$(hw_backtitle)" \
                     --title "Complete reconfiguration" \
                     --menu "   Reconfiguration method " 10 40 3 \
                 1 "Floppy" "Use honeywall.conf configuration file from floppy"\
                 2 "Defaults" "Reconfigure from factory defaults (/etc/honeywall.conf.orig)"\
                 3 "Interview" "Reconfigure through the interview process")

             case ${_opt} in
             1) # Use the floppy
                config_floppy
                ;;

             2) # Use the original factory defaults.
                config_defaults
                ;;

             3) # Start the interview
                /dlg/SetupHoneywall.sh
                ;;
             esac
         fi
         ;;
   esac

   # Make sure that any variable changes are applied.
   #hwctl -r
   # This should be handled in individual scripts before exit. --PWM
done

# NOTREACHED (but exit anyway for good programming form.)
exit 0
