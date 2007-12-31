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
# $Id: argus.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: Allow the user to use argus to see flow summaries on selected
#          snort pcap logfiles.  Easy way to see what's going on and who
#          is talking.

. /etc/rc.d/init.d/hwfuncs.sub
hw_setvars


_TMP=$(mktemp /tmp/.argus.XXXXXXXX)
(cd ${LOGDIR}/pcap; find * -name "log" -ls) |
	awk '{print $11 " " $7 " '${LOGDIR}'/$1 ";}' > ${_TMP}

ls -l ${_TMP}

if [ ! -s ${_TMP} ]; then
    /usr/bin/dialog --stdout --no-shadow \
        --backtitle "$(hw_backtitle)" \
        --title "Status Message" --clear \
        --msgbox "No Snort log files were found." 5 60
    rm -f ${_TMP} &>/dev/null
    exit 1
else
    _opt=$(/usr/bin/dialog --stdout --no-cancel --no-shadow --item-help \
          --backtitle "$(hw_backtitle)" \
          --title "Argus traffic summaries" \
          --menu "   Select Snort log file to analyze (name size)" 20 78 9 \
          `cat ${_TMP}`)
fi

/usr/local/sbin/argus -n /var/run/argus2.pid -w - -r ${LOGDIR}/pcap/${_opt} | rasort -n > ${_TMP}
/usr/bin/dialog --stdout --no-cancel --no-shadow \
   --backtitle "$(hw_backtitle)" \
   --title "Argus flow summaries for ${_opt}" --clear \
   --textbox ${_TMP} 20 78 

rm -f ${_TMP} &>/dev/null

exit 0
