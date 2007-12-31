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
# $Id: Upload.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: To allow the user to configure how the honeywall will upload data
#          to a remote data collection server.

. /etc/init.d/hwfuncs.sub

PATH=$PATH:/usr/bin:/bin

#Let's set some defaults
#echo "22" > ${CONFDIR}/Hw_UP_PORT 
#hw_set Hw_UP_SYSLOG 1

## Upload config disabled for now...
         dialog --stdout --no-shadow \
             --backtitle "$(hw_backtitle)" \
             --title "Upload" --clear \
             --msgbox "Sorry, upload functionality is unavailable." 10 60

exit 0

#############

while true
do
   hw_setvars
   _res=$(dialog --stdout --no-shadow --no-cancel --item-help\
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Upload Configuration"  --clear \
      --menu "          Upload Variables" 20 55 11\
      1 "Return to Honeywall Configuration" "Previous menu"\
      2 "Hostname" "Upload server hostname."\
      3 "Port" "Remote upload server SSH port."\
      4 "Username" "Remote upload server username."\
      5 "Syslog Archive Level" "Syslog archive level (default 1)."\
      6 "Upload Firewall Logs" "Upload the Firewall log files ( 0 or 1 )"\
      7 "Upload Pcap Logs" "Upload the pcap log files ( 0 or 1 )"\
      8 "Obfuscate logs" "Obfuscate pcap and firewall logs ( 0 or 1 )"\
      9 "Obfuscate Honeynet" "Obfuscate the Honeynet (CIDR format /24)"\
      10 "Obfuscation Fake Network" "Network used to obfuscate the Honeynet (CIDR format /24)."\
      11 "Enable" "To enable, add this command to your crontab.")

   case ${_res} in
      1) exit 0
         ;;
      2)
         _tmp=$(dialog --stdout --no-shadow \
                  --backtitle "$(hw_backtitle)" \
                  --title "Upload Variables" --clear \
                  --inputbox "Enter the upload server name or ip." 10 45 "${Hw_UP_HOST}")
         if [ "$?" -eq 0 ]; then
            hw_set Hw_UP_HOST "$_tmp"
         fi
         ;;
      3)
         _tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Upload Variables" --clear \
                 --inputbox "Enter the upload server destination port." 10 45 "${Hw_UP_PORT}")

         if [ "$?" -eq 0 ]; then
            hw_set Hw_UP_PORT "$_tmp"
         fi
         ;;
      4)
         _tmp=$(dialog --stdout --no-shadow \
                  --backtitle "$(hw_backtitle)" \
                  --title "Upload Variables" --clear \
                  --inputbox "Enter the upload server username." 10 45 "${Hw_UP_USER}")

         if [ "$?" -eq 0 ]; then
            hw_set Hw_UP_USER "$_tmp"
         fi
         ;;
      5)
         _tmp=$(dialog --stdout --no-shadow \
                  --backtitle "$(hw_backtitle)" \
                  --title "Upload Variables" --clear \
                  --inputbox "Enter the Syslog archive level." 10 45 "${Hw_UP_SYSLOG}")

         if [ "$?" -eq 0 ]; then
            hw_set Hw_UP_SYSLOG "$_tmp"
         fi
         ;;
      6)
         _opt=$(dialog --no-cancel --stdout --no-shadow --item-help\
             --backtitle "$(hw_backtitle)" \
             --title "Upload Variables" --clear \
             --menu "Upload Firewall Logs." 10 45 2 \
             1 "No" "Do not upload the firewall logs." \
             2 "Yes" "Upload the firewall logs.")

         if [ "${_opt}" -eq 1 ]; then
            hw_set Hw_UP_FWLOG 0
         else
            hw_set Hw_UP_FWLOG 1
         fi
         ;;
      7)
         _opt=$(dialog --no-cancel --stdout --no-shadow --item-help\
             --backtitle "$(hw_backtitle)" \
             --title "Upload Variables" --clear \
             --menu "Upload Pcap Logs." 10 45 2 \
             1 "No" "Do not upload the pcap logs." \
             2 "Yes" "Upload the pcap logs.")

         if [ "${_opt}" -eq 1 ]; then
            hw_set Hw_UP_PCAPLOG 0
         else
            hw_set Hw_UP_PCAPLOG 1
         fi
         ;;
      8)
         _opt=$(dialog --no-cancel --stdout --no-shadow --item-help\
             --backtitle "$(hw_backtitle)" \
             --title "Upload Variables" --clear \
             --menu "Obfuscate logs." 10 45 2 \
             1 "No" "Do not obfuscate logs." \
             2 "Yes" "Obfuscate logs.")

         if [ "${_opt}" -eq 1 ]; then
            hw_set Hw_UP_OBFUSCATE 0
         else
            hw_set Hw_UP_OBFUSCATE 1
         fi
         ;;
      9)
         _tmp=$(dialog --stdout --no-shadow \
                  --backtitle "$(hw_backtitle)" \
                  --title "Upload Variables" --clear \
                  --inputbox "Enter the Honeynet to obfuscaten.  Must be a class C network in CIDR format (i.e. 10.0.2.0/24)." 10 55 "${Hw_UP_SRC}")

         if [ "$?" -eq 0 ]; then
            hw_set Hw_UP_SRC "$_tmp"
         fi
         ;;
      10)
         _tmp=$(dialog --stdout --no-shadow \
                  --backtitle "$(hw_backtitle)" \
                  --title "Upload Variables" --clear \
                  --inputbox "Enter the fake network to use for obfuscation.  Must be a class C network in CIDR format (i.e. 1.1.1.0/24)." 10 55 "${Hw_UP_DEST}")
         if [ "$?" -eq 0 ]; then
            hw_set Hw_UP_DEST "$_tmp"
         fi
         ;;
      11)
         dialog --stdout --no-shadow \
             --backtitle "$(hw_backtitle)" \
             --title "Enable Upload" --clear \
             --msgbox "Add this command to your crontab file to execute the script at your desired time:  /usr/local/bin/upload.sh" 10 60
         ;;
   esac
done

# NOTREACHED (but exit with a return value for god programming form.)
exit 0
