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
# $Id: summary.sh 4392 2006-09-07 02:34:56Z esammons $
#
# PURPOSE: To email the HwALERT_EMAIL user a daily summary.

PATH="/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin"

. /etc/init.d/hwfuncs.sub
hw_setvars

YESTERDAY=`date -d yesterday +"%d %b %Y"`
SNORTDATE=`date -d yesterday +%Y%m%d`
SNORTDIR="${LOGDIR}/snort/${SNORTDATE}"
RESFILE="${SNORTDIR}/summary.log"
_TMP=$(mktemp /tmp/.sum.XXXXXXXX)

#Only send a summary email if the HwALERT_EMAIL is set and the honeynet is set
if [ -n "${HwALERT_EMAIL}" ] && [ -n "${HwLAN_IP_RANGE}" ]; then

   # Create the Snort log directory, if it does not already exist
   if [ ! -d $SNORTDIR ]; then
      install -d -o snort -g snort -m 0755 $SNORTDIR
   fi

   #Run the traffic summary for the past day
   /usr/local/bin/traffic_summary.py -f "${_TMP}" -t 1 --honeynet ${HwLAN_IP_RANGE}

   #Let's move the tmp file to the proper dir
   mv ${_TMP} ${RESFILE} &> /dev/null

   /bin/mail -s "${HwHOSTNAME}'s traffic summary for ${YESTERDAY}" ${HwALERT_EMAIL} < ${RESFILE}

   #Let's compress it
   gzip ${RESFILE}
fi

exit 0
