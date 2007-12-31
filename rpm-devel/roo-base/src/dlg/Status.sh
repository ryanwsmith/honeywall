#!/bin/bash
#
# $Id: Status.sh 2073 2005-08-24 04:04:58Z patrick $
#
# PURPOSE: To give the user status information on the currently running
#          honeywall.
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
hw_setvars

PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

function warnconfigure {
	dialog --no-shadow \
		--backtitle "$(hw_backtitle)" \
		--title "Status"  --clear \
		--msgbox "This Honeywall has not been configured.  Please run Initial Setup from the main menu first." 10 60
	return 0
}


while true
do
   _res=$(dialog --stdout --no-cancel --item-help \
          --backtitle "$(hw_backtitle)" \
          --title "Status" --clear \
          --menu "Status Options" 22 45 16 \
          back "Return to main menu" "Returns to main menu" \
          1 "Network Interface" "Displays the current configurations/status of the network interface cards." \
          2 "Honeywall.conf" "Displays the Honeywall configurations file (/etc/honeywall.conf)." \
          3 "Firewall Rules" "Displays the current iptables ruleset." \
          4 "Running processes" "Displays the current running processes on the Honeywall gateway." \
          5 "Listening ports" "Displays LISTENing open ports (by default, should have nothing)." \
          6 "Snort_inline Alerts-fast" "Displays any alerts generated for that day by Snort-Inline (fast mode)." \
          7 "Snort_inline Alerts-full" "Displays any alerts generated for that day by Snort-Inline (full mode)." \
          8 "Snort Alerts" "Displays any alerts generated that day by Snort." \
          9 "System Logs" "Displays system logs (/var/log/messages)." \
          10 "Inbound Connections" "Looks for Inbound Connections in Honeywall Logs." \
          11 "Outbound Connections" "Looks for Outbound Connections in Honeywall Logs."\
	  12 "Dropped Connections" "Connections that have been dropped because the limit has been reached." \
          13 "tcpdstat Traffic Statistics" "Statistics for Snort traffic captures"\
          14 "Argus Flow Summaries" "Flow Summaries for Snort traffic captures"\
          15 "Tracked Connections" "Connections Currently Tracked by iptables")
   case ${_res} in
      back)
         exit 0
         ;;
      1)
         _TMP=$(mktemp /tmp/.ifconfig.XXXXXXXX)
         ifconfig -a > ${_TMP}

         dialog --stdout --no-cancel \
          --backtitle "$(hw_backtitle)" \
          --title "Network Interface Information" --clear \
          --textbox ${_TMP} 20 78 

         rm -f ${_TMP} &>/dev/null
         ;;
      2) 
         #update honeywall.conf before showing it
	if [ $(hw_isconfigured) -eq 1 ]; then
		dumpvars /etc/honeywall.conf
		dialog --stdout --no-cancel \
			--backtitle "$(hw_backtitle)" \
			--title "Honeywall.conf" --clear \
			--textbox /etc/honeywall.conf 25 78
	else
		warnconfigure
	fi
	;;

      3)
         _TMP=$(mktemp /tmp/.iptables.XXXXXXXX)
         iptables -L -n -v > ${_TMP}

         dialog --stdout --no-cancel \
          --backtitle "$(hw_backtitle)" \
          --title "Firewall Rules" --clear \
          --textbox ${_TMP} 25 78

         rm -f ${_TMP} &> /dev/null
         ;;

      4)
         _TMP=$(mktemp /tmp/.ps.XXXXXXXX)
         ps -aux > ${_TMP}

         dialog --stdout --no-cancel \
            --backtitle "$(hw_backtitle)" \
          --title "Running processes" --clear \
          --textbox ${_TMP} 25 78

         rm -f ${_TMP} &> /dev/null
         ;;
      5)
         _TMP=$(mktemp /tmp/.netstat.XXXXXXXX)
         netstat -pan -A inet > ${_TMP}

         dialog --stdout --no-cancel \
          --backtitle "$(hw_backtitle)" \
          --title "Listening ports" --clear \
          --textbox ${_TMP} 25 78

         rm -f ${_TMP} &> /dev/null
         ;;

      6)
	if [ $(hw_isconfigured) -eq 1 ]; then
		#Get today's date
		DIR="${LOGDIR}/snort_inline"
		#DATE=$(date +%b_%d)
		DATE=$(date +%Y%m%d)
		FILE="${DIR}/${DATE}/snort_inline-fast"
		#FILE="${DIR}/snort_inline-fast"

		if [ -e ${FILE} ]; then
		    dialog --stdout --no-cancel \
		       --backtitle "$(hw_backtitle)" \
		       --title "Snort_inline Alerts (fast) for ${DATE}" --clear \
		       --textbox ${FILE} 25 78
		else
		    dialog --stdout --no-cancel \
		       --backtitle "$(hw_backtitle)" \
		       --title "Snort_inline Alerts for ${DATE}" --clear \
		       --msgbox "${FILE} does not exists yet.  Probably haven't dropped any packets today yet!" 25 78
		fi
	else
		warnconfigure
	fi
	;;
      
      7)
	if [ $(hw_isconfigured) -eq 1 ]; then
		#Get today's date
		DIR="${LOGDIR}/snort_inline"
		#DATE=$(date +%b_%d)
		DATE=$(date +%Y%m%d)
		FILE="${DIR}/${DATE}/snort_inline-full"
		#FILE="${DIR}/snort_inline-full"

		if [ -e ${FILE} ]; then
		    dialog --stdout --no-cancel \
		       --backtitle "$(hw_backtitle)" \
		       --title "Snort_inline Alerts (full) for ${DATE}" --clear \
		       --textbox ${FILE} 25 78
		else
		    dialog --stdout --no-cancel \
		       --backtitle "$(hw_backtitle)" \
		       --title "Snort_inline Alerts for ${DATE}" --clear \
		       --msgbox "${FILE} does not exists yet.  Probably haven't dropped any packets today yet!" 25 78
		fi
	else
		warnconfigure
        fi
        ;;


      8)
	if [ $(hw_isconfigured) -eq 1 ]; then
		#Get today's date
		DIR="${LOGDIR}/snort"
		#DATE=$(date +%b_%d)
		DATE=$(date +%Y%m%d)
		FILE="${DIR}/${DATE}/snort_full"
		#FILE="${DIR}/snort_full"

		if [ -e ${FILE} ]; then
		    dialog --stdout --no-cancel \
		       --backtitle "$(hw_backtitle)" \
		       --title "Snort Alerts for ${DATE}" --clear \
		       --textbox ${FILE} 25 78
		else
		    dialog --stdout --no-cancel \
		       --backtitle "$(hw_backtitle)" \
		       --title "Snort Alerts for ${DATE}" --clear \
		       --msgbox "${FILE} does not exists yet.  Probably haven't alerted on any packets yet!" 25 78
		fi
	else
		warnconfigure
        fi
        ;;

      9)
         dialog --stdout --no-cancel \
          --backtitle "$(hw_backtitle)" \
          --title "System Logs" --clear \
          --textbox /var/log/messages 25 78
         ;;

      10)
         _TMP=$(mktemp /tmp/.inbound.XXXXXXXX) 
         `cat ${LOGDIR}/iptables | grep INBOUND > ${_TMP}`
                                                                                
         dialog --stdout --no-cancel \
          --backtitle "$(hw_backtitle)" \
          --title "Inbound Connections" --clear \
          --textbox ${_TMP} 20 78
                                                                                
         rm -f ${_TMP} &>/dev/null
         ;;

      11) 
         _TMP=$(mktemp /tmp/.outbound.XXXXXXXX) 
         `cat ${LOGDIR}/iptables | grep OUTBOUND > ${_TMP}`
                                                                                
         dialog --stdout --no-cancel \
          --backtitle "$(hw_backtitle)" \
          --title "Outbound Connections" --clear \
          --textbox ${_TMP} 20 78
                                                                                
         rm -f ${_TMP} &>/dev/null
         ;;

      12) 
         _TMP=$(mktemp /tmp/.drop.XXXXXXXX) 
         `cat ${LOGDIR}/iptables | grep Drop > ${_TMP}`
                                                                                
         dialog --stdout --no-cancel \
          --backtitle "$(hw_backtitle)" \
          --title "Dropped Connections" --clear \
          --textbox ${_TMP} 20 78
                                                                                
         rm -f ${_TMP} &>/dev/null
         ;;
      13)
         /dlg/status/tcpdstat.sh
         ;;
      14)
         /dlg/status/argus.sh
         ;;
      15)
         /dlg/status/conntrack.sh
         ;;
   esac
done
