#!/bin/sh
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
# $Id: hwreset_tally.sh 1974 2005-08-13 01:43:35Z patrick $
#
# Idea barrowed from: http://sial.org/howto/linux/pam_tally/reset_failed_logins
# Thanks!
#
# Clear failed login counts for pam_tally, log results to syslog. Only
# tested on RedHat Linux.

RESULTS=$(/sbin/pam_tally --reset)

if [ ! -z "${RESULTS}" ]; then
  /usr/bin/logger -i -p authpriv.info -t pam_tally -- "${RESULTS}"
fi

exit 0

