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
# $Id: dns2resolv.sh 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: Creating /etc/resolv.conf.  As originally written,
#          this script required the user pass in the new
#          contents of HwMANAGE_DNS as argument $1.  Now if no
#          arguments are given, just recreate /etc/resolv.conf
#          from the existing value of HwMANAGE_DNS.

. /etc/rc.d/init.d/hwfuncs.sub

PATH=/usr/bin:/sbin:/bin

TMP="$(hw_mktemp dns2resolv)"
R=/etc/resolv.conf
trap "rm -f $TMP" EXIT INT TERM

cp /dev/null $TMP
if [ $? -ne 0 ]; then
	echo "$0: cannot not write to $TMP"
	exit 1
fi

echo "# File created by dns2resolv.sh" > $TMP

DOMAIN="$(hw_get HwDOMAIN)"
if [ "x$DOMAIN" != "x" ]; then
	echo "domain $DOMAIN" >> $TMP
fi

# Get current state
servers="$(hw_get HwMANAGE_DNS)"
if [ "x$1" != "x" ]; then
	# Were we told to set this to the same value it has now?
	if [ "$servers" != "$1" ]; then
		HwMANAGE_DNS=$1
		hw_set HwMANAGE_DNS "$1"
	fi
else
	# Not passed anything.  Use current value.
        HwMANAGE_DNS="$servers"
fi

#Let's add each nameserver to the /etc/resolv.conf
for ip in $HwMANAGE_DNS; do
   echo "nameserver ${ip}" >> $TMP
done

# We made it.  Now re-write the original file, after
# making a backup file first (just in case.)
cp $R $R.bak
mv $TMP $R
chmod 644 $R

exit 0
