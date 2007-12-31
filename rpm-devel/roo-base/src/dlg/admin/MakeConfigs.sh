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
# $Id: MakeConfigs.sh 2004 2005-08-17 18:11:58Z dittrich $
#
# PURPOSE: Used to manage the configuration subsystem.  This is where the 
#          user can read in new honeywall.conf files from a floppy or copy the
#          existing configuraiton to floppy.

. /etc/rc.d/init.d/hwfuncs.sub
hw_setvars

PATH=/usr/local/bin:${PATH}

while true
do

    #Configuration file management Interface

    _opt=$(/usr/bin/dialog --stdout --no-cancel --no-shadow \
            --backtitle "$(hw_backtitle)" \
            --title "Management Configuration Subsystem menu" \
            --menu "   Configuration Options" 15 60 5 \
            1 "Back to Administration menu" \
            2 "Create /etc/honeywall.conf from ${CONFDIR} files" \
            3 "Create ${CONFDIR} files from /etc/honeywall.conf" \
            4 "Create ${CONFDIR} files from floppy disk" \
            5 "Write /etc/honeywall.conf files to floppy disk")

    case ${_opt} in
        1)
            exit 0
            ;;
        2)
            /usr/bin/dialog --no-shadow \
                    --backtitle "$(hw_backtitle)" \
                    --title "Rebuild /etc/honeywall.conf?"  \
                    --defaultno --clear \
                    --yesno "Rebuild /etc/honeywall.conf from configuration subsystem in /hw/conf?" 15 45

            case $? in
                0)
                    /usr/bin/dialog --no-shadow \
                            --backtitle "$(hw_backtitle)" \
                            --title "WARNING: /etc/honeywall.conf will be overwritten!"  \
                            --defaultno --clear \
                            --yesno "This action will rebuild /etc/honeywall.conf.  Are you sure you want to proceed?" 15 45

                    case $? in
                        1) 
                            exit 0
                            ;;
                    esac

                # Rebuild the honeywall.conf file from the configuration 
                # subsystem  files in /hw/conf
                dumpvars /etc/honeywall.conf
                ;;
            esac
            ;;
        3)
            /usr/bin/dialog --no-shadow \
                    --backtitle "$(hw_backtitle)" \
                    --title "Rebuild configuration subsystem?"  \
                    --defaultno --clear \
                    --yesno "Rebuild configuration subsystem in /hw/conf from settings in /etc/honeywall.conf?" 15 45

            case $? in
                0)
                    /usr/bin/dialog --no-shadow \
                            --backtitle "$(hw_backtitle)" \
                            --title "WARNING: configuration subsytem will be rebuilt!"  \
                            --defaultno --clear \
                            --yesno "This action will rebuild the configuration subsystem (which is used to boot the Honeywall). Are you sure you want to proceed?" 15 45

                    case $? in
                        1) 
                            exit 0
                            ;;
                    esac

                    # Populate the configuration directory with the 
                    # honeywall.conf file 
                    if [ -f /etc/honeywall.conf ]; then
                        loadvars < /etc/honeywall.conf
                    else
                        exit 0
                    fi
                    ;;
            esac
            ;;
        4)
            /usr/bin/dialog --no-shadow \
                    --backtitle "$(hw_backtitle)" \
                    --title "Rebuild configuration subsystem?"  \
                    --defaultno --clear \
                    --yesno "Rebuild configuration subsystem in /hw/conf from settings on floppy disk?" 15 45

	    mcopy -n a:/honeywall.conf /tmp &> /dev/null
	    if [ $? -eq 1 ]; then
	        # Explain to user that there isn't a config file on
		# floppy.
                /usr/bin/dialog --no-shadow \
                        --backtitle "$(hw_backtitle)" \
                        --title "There was no configuration file found on floppy."  \
                        --defaultno --clear \
                        --ok "Go back to menu" 14 55

                case $? in
                    1) 
                        exit 0
                        ;;
                esac
            else
	        # Double check they really want to do this.
                case $? in
                    0)
                      /usr/bin/dialog --no-shadow \
                          --backtitle "$(hw_backtitle)" \
                          --title "WARNING: configuration subsytem will be rebuilt!"  \
                          --defaultno --clear \
                          --yesno "This action will rebuild the configuration subsystem (which is used to boot the Honeywall). Are you sure you want to proceed?" 15 45

                      case $? in
                          1) 
                             exit 0
                             ;;
                      esac

                      # Populate the configuration directory with the 
                      # honeywall.conf file 
                      mv /tmp/honeywall.conf /etc/honeywall.conf
                      loadvars < /etc/honeywall.conf
                      ;;
                esac
            fi
            ;;
        5)
            mcopy -o /etc/honeywall.conf a:honeywall.conf >/dev/null 2>&1
            if [ $? -eq 1 ]; then
                # Explain to user that there isn't a config file on
                # floppy.
                /usr/bin/dialog --no-shadow \
                        --backtitle "$(hw_backtitle)" \
                        --title "Failed to write /etc/honeywall.conf to floppy."  \
                        --defaultno --clear \
                        --msgbox "Go back to menu" 14 55

                case $? in
                    1)
                        exit 0
                        ;;
                esac
            fi
            ;;
    esac
done

exit 0
