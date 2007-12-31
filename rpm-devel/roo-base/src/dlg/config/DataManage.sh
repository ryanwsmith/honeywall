#!/bin/bash
#
# Copyright (C) 2005 The Trustees of Indiana University.  All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
#

#----- DataManage.sh
#-----
#----- Controls storage limits for pcap and hflow data
#-----
#-----
#----- Version: $Id: DataManage.sh 4565 2006-10-18 16:56:43Z esammons $
#-----
#----- Authors: Camilo Viecco <cviecco@indiana.edu>
#-----          Earl Sammons <esammons@hush.com>


. /etc/rc.d/init.d/hwfuncs.sub

HWDAEMONS="/etc/init.d/hwdaemons"
PATH=${PATH}:/usr/bin:/bin
DEFAULT_PCAP_KEEP_DAYS=45
DEFAULT_DB_KEEP_DAYS=180

while true 
do
   # Get the variables we care about
   HwPCAPDAYS="$(hw_get HwPCAPDAYS)"
   HwDBDAYS="$(hw_get HwDBDAYS)"

   # Now enforce defaults, if none already set
   if [ -z "${HwPCAPDAYS}" ]; then
       hw_set HwPCAPDAYS "${DEFAULT_PCAP_KEEP_DAYS}"
   fi

   if [ -z "${HwDBDAYS}" ]; then
       hw_set HwDBDAYS "${DEFAULT_DB_KEEP_DAYS}"
   fi

   # Just in case...
   HwPCAPDAYS="$(hw_get HwPCAPDAYS)"
   HwDBDAYS="$(hw_get HwDBDAYS)"

   _res=$(dialog --stdout --no-shadow --no-cancel --item-help \
      --backtitle "$(hw_backtitle)" \
      --title "Honeywall Configuration"  --clear \
      --menu "   Data Managemnt List Variables" 20 65 9\
      1 "Back to Honeywall Configuration menu" "Previous menu" \
      2 "Update Days to keep Pcap data, Currently: ${HwPCAPDAYS}" "Update number of days to retain pcap data." \
      3 "Update Days to keep DB data, Currently: ${HwDBDAYS}" "Update number of days to retain DB data."\
      4 "Purge Pcap Data older than ${HwPCAPDAYS} days" "Purge Pcap data ."\
      5 "Purge DB Data older than ${HwDBDAYS} days" "Purge DB data ."\
      6 "Purge ALL Pcap Data" "Purge ALL Pcap data ."\
      7 "Purge ALL DB Data" "Purge ALL DB data ."\
      8 "Purge ALL Pcap AND DB Data" "Purge ALL Pcap and DB Data")

   case ${_res} in
      1) exit 0 ;;

      2)
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Days to keep Pcap Data "  --clear \
                 --inputbox " Enter the number of days to retain Pcap Data" 10 45 ${HwPCAPDAYS})

         if [ "$?" -eq 0 ]; then
            hw_set HwPCAPDAYS "$tmp"
         fi
         ;;

      3) 
         tmp=$(dialog --stdout --no-shadow \
                 --backtitle "$(hw_backtitle)" \
                 --title "Days to keep DB data"  --clear \
                 --inputbox " Enter the number of days to retain DB Data" 10 45 ${HwDBDAYS})

         if [ "$?" -eq 0 ]; then
            hw_set HwDBDAYS "$tmp"
         fi
         ;;

      4) /dlg/config/purgePcap.pl ${HwPCAPDAYS} ;;

      5) /dlg/config/purgeDB.pl ${HwDBDAYS} ;;

      6) /dlg/config/purgePcap.pl 0 ;;

      7) /dlg/config/purgeDB.pl 0 ;;

      8)
	/dlg/config/purgeDB.pl 0 
	/dlg/config/purgePcap.pl 0 
	;;
   esac
done

# NOTREACHED (but exit anyway for good programming form.)
exit 0
