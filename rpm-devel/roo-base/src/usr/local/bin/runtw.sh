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

# simple program to run tripwire and report findings

HOST=`/usr/local/bin/hwctl -n HwHOSTNAME`
ALERT_TO=`/usr/local/bin/hwctl -n HwALERT_EMAIL`

if [ -z "$HOST" ] ; then
    HOST=`/bin/hostname`
fi

if [ -z "$ALERT_TO"  ] ; then
    ALERT_TO=root@localhost
fi

/usr/sbin/tripwire -m c |mail -s "Tripwire Report from $HOST" $ALERT_TO
