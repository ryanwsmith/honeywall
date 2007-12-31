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
# $Id: DirectoryInitialization.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: Used to create all necessary Honeywall directories.  Mainly used if
#          the user wants to manually setup and configure his or her honeywall.

. /etc/rc.d/init.d/hwfuncs.sub
hw_setvars

########################################################################
# This function is disabled for now, until we fix it so it works
# with roo.
hw_disabled DirectoryInitialization
exit 0
########################################################################

#/usr/bin/dialog --no-shadow \
#        --backtitle "$(hw_backtitle)" \
#        --title "Create Honeywall directories?"  --defaultno --clear \
#        --yesno "Create directories for storing logs and configuration data?" 15 45
#
#case $? in
#    0)
#    echo "Beginning Honeywall directory creation."
#    sleep ${HwSLEEP}
#    _disk=$(hw_havedisk)
#
#    # Look for 1 or more partitions on the drive.
#    hw_partcheck "${_disk}"
#    if [ $(hw_errchk "$?" "No partitions found on ${_disk}") = 1 ]; then
#        exit 1 
#    fi
#
#    # Look for a mountable filesystem on first partition.
#    hw_mount_hw "${_disk}1"
#
#    # Now create the Honeywall directory structure and populate it.
#    hw_create_hw_link
#    hw_createhwdirs
#    if [ $(hw_errchk "$?" "Directory creation failure.  Exiting...") = 1 ]; then
#        exit 1
#    fi
#
#    echo 'Honeywall directory creation successful.'
#    sleep ${HwSLEEP}
#    ;;
#esac
