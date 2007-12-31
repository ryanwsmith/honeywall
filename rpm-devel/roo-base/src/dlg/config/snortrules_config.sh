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
# PURPOSE: set up automatic snort rule updates

####################################################################
# Must be root to run this
if [ "${UID}" -ne 0 ]; then
        echo ""
        echo "$0: Only \"root\" can run $0"
        echo ""
        exit 1
fi
####################################################################
while true
do

PATH=${PATH}:/usr/bin:/sbin:/bin
. /etc/rc.d/init.d/hwfuncs.sub
hw_setvars

FIX_CRON="/dlg/config/snortrules_cron.sh"

##############################################################################
get_oinkcode() {
if [ -z "${HwOINKCODE}" ]; then
  dialog --stdout --no-shadow \
      --backtitle "$(hw_backtitle)" \
      --title "Snort® VRT Rules Update Setup"  --clear \
      --msgbox "\nAn \"Oink Code\" is required to update the installed Sourcefire® VRT Cerified Snort® Rules.  Free registration is required to obtain an \"Oink Code\".  Please see local docs[1] or the online manual[2] for more info.\n\n \
[1] /hw/docs/README.snortrules \n \
[2] http://www.honeynet.org/tools/cdrom/roo/maanual\n\n" 14 60
fi
   OINK_CHECK_OK="no"
   while [ "${OINK_CHECK_OK}" == "no" ]; do
      tmp=$(dialog --stdout --no-shadow \
       --backtitle "$(hw_backtitle)" \
       --title "Oink Code"  --clear \
       --inputbox " Please enter your Oink Code below which is required update Snort® VRT rules.  Info on obtaining an Oink Code on roo: \n\n \
    /hw/docs/README.snortrules\n\n \
 or in the online manual:\n\n \
http://www.honeynet.org/tools/cdrom/roo/manual/ \n\n \
 Oink Code: \n" 18 55 "${HwOINKCODE}")

      if [ $? -eq 0 ]; then
   	   if [ -z "$(echo ${tmp} | sed 's/[[:alnum:]]//g')" ]; then
		hw_set HwOINKCODE "${tmp}"
		OINK_CHECK_OK="yes"
   	   else
# set whatever they entered even though it's bogus to make it easier to fix...
# Since oink codes are 40 bit strings ;P
		HwOINKCODE=${tmp}
		dialog --sleep 7 \
			--backtitle "$(hw_backtitle)" \
			--title "Oink Code Input Error!" \
       			--infobox "\nOink Code only contains characters:\n\n         a-z, A-Z, and 0-9 \n\n         Please try again!" 10 40
   	   fi
      elif	[ $? -eq 1 ]; then
	  exit 0
      fi
   done
}
##############################################################################
configure_auto_updates() {
# Daily or Weekly Updates?
# figure out curent val... simplest guess...
DAILY_VAL=off
WEEKLY_VAL=off
if [ -n "${HwRULE_DAY}" ]; then
	WEEKLY_VAL=on
else
	DAILY_VAL=on
fi	
DAY_OR_WEEK=$(dialog --stdout --no-shadow \
	--backtitle "$(hw_backtitle)" \
	--title "Snort Rule Update Frequency" --clear \
        --radiolist "\nUpdate Snort Rules Daily or Weekly?\n\n" 18 50 5 \
        "Daily"  "Update rules once per day" "${DAILY_VAL}" \
        "Weekly" "Update rules once per week" "${WEEKLY_VAL}" )

case $? in
  0) if [ "${DAY_OR_WEEK}" == "Daily" ]; then
# Setting HwRULE_DAY to "" means daily updates
	hw_set HwRULE_DAY ""
     fi
  ;;
  *) exit 0
  ;;
esac

# We have to ask for the day of week if they want weekly updates
if [ "${DAY_OR_WEEK}" == "Weekly" ]; then
# Figure out which day is currently chosen... if none, all will be "off" and it just highlights one
# Seriosuly, now... isnt this pushing the shell a bit ;P
  DAYS=( sun mon tue wed thu fri sat )
	for i in 0 1 2 3 4 5 6; do
		if [ "${HwRULE_DAY}" = "${DAYS[${i}]}" ]; then
			DAY[${i}]=on
        	else
                	DAY[${i}]=off
        	fi
	done

	tmp=$(dialog --stdout --no-shadow \
	--backtitle "$(hw_backtitle)" \
	--title "Day to perform automated Snort Rule Updates" --clear \
        --radiolist "\nPlease choose the day of week you want Snort rules to be \
automatically updated on.\n \n" 18 50 7 \
	"sun" "Sunday" "${DAY[0]}" \
        "mon" "Monday" "${DAY[1]}" \
        "tue" "Tuesday" "${DAY[2]}" \
	"wed" "Wednesday" "${DAY[3]}" \
	"thu" "Thursday" "${DAY[4]}" \
	"fri" "Friday" "${DAY[5]}" \
	"sat" "Saturday" "${DAY[6]}")
    case $? in
	0) hw_set HwRULE_DAY "${tmp}"
	;;
	*) exit 0
	;;
    esac
fi

# Need the Hour either way (weekly or daily)
# Figure out which day is currently chosen... if none, all will be "off" and it just highlights one
# More shell sickness...
	for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23; do
		if [ "${HwRULE_HOUR}" = "${i}" ]; then
			HOUR[${i}]=on
        	else
                	HOUR[${i}]=off
        	fi
	done
tmp=$(dialog --stdout --no-shadow \
	--backtitle "$(hw_backtitle)" \
	--title "Snort Rule Update Time" --clear \
        --radiolist "\nPlease choose the Hour you want Snort rules to be \
automatically updated on.\n \n" 18 50 7 \
 	 "0"  "Midnight" "${HOUR[0]}" \
         "1"  "1AM" "${HOUR[1]}" \
         "2"  "2AM" "${HOUR[2]}" \
	 "3"  "3AM" "${HOUR[3]}" \
	 "4"  "4AM" "${HOUR[4]}" \
	 "5"  "5AM" "${HOUR[5]}" \
	 "6"  "6AM" "${HOUR[6]}" \
	 "7"  "7AM" "${HOUR[7]}" \
	 "8"  "8AM" "${HOUR[8]}" \
	 "9"  "9AM" "${HOUR[9]}" \
	"10" "10AM" "${HOUR[10]}" \
	"11" "11AM" "${HOUR[11]}" \
	"12" "12PM" "${HOUR[12]}" \
	"13"  "1PM" "${HOUR[13]}" \
	"14"  "2PM" "${HOUR[14]}" \
	"15"  "3PM" "${HOUR[15]}" \
	"16"  "4PM" "${HOUR[16]}" \
	"17"  "5PM" "${HOUR[17]}" \
	"18"  "6PM" "${HOUR[18]}" \
	"19"  "7PM" "${HOUR[19]}" \
	"20"  "8PM" "${HOUR[20]}" \
	"21"  "9PM" "${HOUR[21]}" \
	"22" "10PM" "${HOUR[22]}" \
	"23" "11PM" "${HOUR[23]}")

case $? in
   0) hw_set HwRULE_HOUR "${tmp}"
    ;;
   *) exit 0
    ;;
esac

  dialog --no-shadow --clear --backtitle "$(hw_backtitle)" \
    --yes-label "Enable" --no-label "Disable" \
    --title "Enable Automatic Snort Rule Updates?" \
    --yesno "\nEnable or Disable Automatic Snort rule updates" 10 45

 
case $? in
   0) hw_set HwRULE_ENABLE yes
    ;;
   1) hw_set HwRULE_ENABLE no
    ;;
esac

  dialog --no-shadow --clear --defaultno --backtitle "$(hw_backtitle)" \
    --title "Auto restart Snort after Rule Updates?" \
    --yesno "\nWARNING - No checks in place to verify safe restarts! Enable at your own risk!\n" 10 50
 
case $? in
   0) hw_set HwSNORT_RESTART yes
    ;;
   1) hw_set HwSNORT_RESTART no
    ;;
esac

}
##############################################################################
configure_manual_updates() {
  dialog --no-shadow --clear --defaultno --backtitle "$(hw_backtitle)" \
    --title "Auto restart Snort after Rule Updates?" \
    --yesno "\nWARNING - No checks in place to verify safe restarts! Enable at your own risk!\n" 10 50
 
case $? in
   0) hw_set HwSNORT_RESTART yes
    ;;

   1) hw_set HwSNORT_RESTART no
    ;;
esac
# Manual updates...
hw_set HwRULE_ENABLE no

}
##############################################################################
enable_rules() {
# Already configured?

if [ "${HwRULE_HOUR}" -ge "0" -a "${HwRULE_HOUR}" -le "23" ]; then
	HOUR="good"
else
	HOUR="bad"
fi

if [ -n "${HwOINKCODE}" -a "${HOUR}" == "good" ]; then
# Yup
	hw_set HwRULE_ENABLE yes
	${FIX_CRON}
else
# Nope
	dialog --no-shadow --sleep 7 \
	--backtitle "$(hw_backtitle)" \
	--title "Error!" \
       	--infobox "\n\n\n Please configure auto rule updates \n  before attempting to enable." 10 41

fi
}

##############################################################################
##############################################################################

_opt=$(dialog --stdout --no-shadow --clear --item-help\
          --backtitle "$(hw_backtitle)" \
          --title "Honeywall Configuration" \
          --menu "    Automatic Snort Rule Update Options" 12 45 6 \
	back "Return to previous menu" "Return to previous menu"\
	  1 "Configure automatic rule updates" "Configure automatic Snort rule update process"\
	  2 "Configure manual rule updates" "Configure manual Snort rule update process"\
          3 "Enable automatic rule updates" "Enable automatic Snort rule updates"\
          4 "Disable automatic rule updates" "Disable automatic Snort rule updates"\
          5 "Update Oinkcode for auto updates" "Update Oinkcode for automatic updates")

if [ $? -eq 0 ]; then
  case ${_opt} in
   back) exit 0
	;;
      1) get_oinkcode
	configure_auto_updates
	${FIX_CRON}
	;;
      2) get_oinkcode
	configure_manual_updates
	${FIX_CRON}
	;;
      3) enable_rules
	;;
      4) hw_set HwRULE_ENABLE no
	${FIX_CRON}
	;;
      5) get_oinkcode
	;;
  esac
elif [ $? -eq 1 ]; then
	exit 0
fi

done


exit 0

