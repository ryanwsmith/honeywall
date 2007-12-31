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

# PURPOSE: set up a cron entry for snort rules updates

. /etc/rc.d/init.d/hwfuncs.sub
PATH=/usr/bin:/sbin:/bin:${PATH}
hw_setvars

CRONTAB="/etc/crontab"
RULE_CMD="/hw/sbin/hwruleupdate --update-rules"

########################################################################
clean_crontab() {
sed -i '/hwruleupdate/d' ${CRONTAB}
}

########################################################################
restart_cron() {
/sbin/service crond reload
}

########################################################################

if [ "${HwRULE_ENABLE}" = "no" ]; then
# Just disabling
	clean_crontab
	restart_cron
	exit 0
elif [ "${HwRULE_ENABLE}" = "yes" ]; then
# Validate HwRULE_HOUR
    if [ "${HwRULE_HOUR}" -ge "0" -a "${HwRULE_HOUR}" -le "23" ]; then
# If HwRULE_DAY is set to a real day, use it...
	case "${HwRULE_DAY}" in
	[Ss]un|[Mm]on|[Tt]ue|[Ww]ed|[Tt]hu|[Ff]ri|[Ss]at)
		clean_crontab
		echo "0 ${HwRULE_HOUR} * * ${HwRULE_DAY} root ${RULE_CMD}" >> ${CRONTAB}
		restart_cron
		exit 0
		;;
# If HwRULE_DAY is null or invalid, we're doing daily updates at HwRULE_HOUR
		*)
		clean_crontab
		echo "0 ${HwRULE_HOUR} * * * root ${RULE_CMD}" >> ${CRONTAB}
		restart_cron
		exit 0
		;;
	esac
    else
	echo "Invalid value for HwRULE_HOUR: ${HwRULE_HOUR}"
    fi
fi


#If we get here, theres a variable set wrong or we were just installed (all vars are null)

#echo "something's wrong?" 
#for i in HwRULE_ENABLE HwRULE_HOUR HwRULE_DAY; do
#	hwctl ${i}
#done

# for dialog...
#sleep 2

exit 0
