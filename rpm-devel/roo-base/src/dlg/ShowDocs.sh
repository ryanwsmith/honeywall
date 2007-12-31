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
# $Id: ShowDocs.sh 4517 2006-10-11 18:19:35Z esammons $
#
# PURPOSE:  This script generates a list of all documents found
#           in the specified path, allowing the user to select
#           which one they wish to view.  This allows a general
#           interface to a documentation directory, allowing
#           someone to customize the documentation directory
#           by simply adding or deleting files.
#           the appropriate document.
#
# Usage: ShowDocs.sh /path/to/docs

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

function viewfile() {

if [ "$1" != "" ]; then
	dialog  \
	      --clear \
	      --no-shadow \
	      --backtitle "${hw_backtitle}" \
	      --title $1 \
	      --textbox $1 25 78
fi
}

_TMP=$(mktemp /tmp/.doclist.XXXXXXXX)
trap "rm -f $_TMP 2>/dev/null; exit 0" INT TERM

# Make sure a directory was given.  We gotta have *something* to show
# the user...
DIR="$1"
if [ "x$DIR" = "x" ]; then
   echo "$0: usage $0 directory"
   exit 1
fi

if [ ! -d "$DIR" ]; then
   echo "$0: directory not found: $DIR"
   exit 1
fi

# Now generate a list of all .txt files in this directory and give
# the user a list from which to select.

(echo 'Return_to_Previous_Menu'; \
  cd $DIR; find * -type f -maxdepth 0 -ls) |
	awk 'BEGIN { n=0;}
	     {print n " " $(NF); n=n+1;}' > ${_TMP}

if [ ! -s ${_TMP} ]; then
    dialog --clear \
	--backtitle "${hw_backtitle}" \
	--title "Null" --clear \
	--msgbox "No files were found in $DIR." 5 60
    rm -f ${_TMP} 2>/dev/null
    exit 1
fi

while true
do
    _opt=$(dialog \
	  --stdout \
	  --no-cancel \
	  --backtitle "${hw_backtitle}" \
	  --title "Documentation" \
	  --menu "Select a document to view" \
	  20 60 14 \
	  `cat ${_TMP}`)

    if [ $_opt -eq 0 ]; then
        rm -f ${_TMP} 2>/dev/null
        exit 0
    else
        FILE=`grep "^$_opt " $_TMP | awk '{ print $2;}'`
        viewfile "$DIR/$FILE"
    fi
done

exit 0
