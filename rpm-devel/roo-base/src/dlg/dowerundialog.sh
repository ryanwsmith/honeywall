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
# $Id: dowerundialog.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: To see if we need to run the dialog menu at startup
. /etc/rc.d/init.d/hwfuncs.sub

#Set honeywall variables
hw_setvars

# Check to see if the honeywall is initialized or not.
# (Fix this.  -- dittrich)
if [ "${HwINIT_SETUP}" != "done" ]; then
    # Run /usr/sbin/menu instead, until we get these
    # two programs combined into one.
    #/dlg/dialogmenu.sh
    /usr/sbin/menu
fi
exit 0
