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
# $Id: honeywall_init.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: Consolidated rc script for honeywall functionality.

. /etc/rc.d/init.d/hwfuncs.sub
. /etc/rc.d/init.d/functions

# Determine, via "status", whether some service is running or not.
# If it is running, restart it.  If it is not running, just start it.
# (This would be better done in the scripts themselves, so that the
# logic as to how to run the script is not required at every location
# where the script may be run.

startOrRestart() {
    $1 status
    if [ $? -eq 1 ]; then
        $1 start
    else
        $1 restart
    fi
}


# Main body

# Now only start those things that do require the honeywall
# be configured first, and don't rely on honeywall variables
# (so they won't be started/restarted by hwctl -r).


#--- removing this cause it doesnt belong
#if [ $(hw_isconfigured) -eq 1 ]; then
#   hw_setvars
#
#   startOrRestart /etc/rc.d/init.d/hflow-mysqld
#
#fi

exit 0
