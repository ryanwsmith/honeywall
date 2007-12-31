#!/bin/bash
#
# $Id: bootcustom.sh 4788 2006-11-17 16:09:14Z esammons $
#
# bootcustom.sh is the hook that handles customization of boot
# time execution.

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin:/usr/local/sbin

. /etc/rc.d/init.d/hwfuncs.sub

# Use to redirect all normal output to /var/log/install.log.
LOG=" /var/log/install.log"

mcopy -n a:/honeywall.conf /etc/honeywall.conf &> /dev/null
if [ $? -eq 1 ]; then
	echo "No a:honeywall.conf found...on floppy" >> $LOG

	mv /tmp/roo/honeywall.conf /etc/honeywall.conf &> /dev/null
	if [ $? -eq 1 ]; then
		echo "No honeywall.conf found...on cd" >> $LOG

	else
		hwctl -p /etc/honeywall.conf
		cp /etc/honeywall.conf /etc/honeywall.conf.orig
	#	hw_startHoneywall
# Overkill but *much* more reliable and this is a one-time-thing
		/etc/init.d/hwdaemons restart
		echo "honeywall.conf found and loaded...from CDROM" >> $LOG
	fi
else
	#found honeywall.conf (from cd), moved to /etc/honeywall.conf
	hwctl -p  /etc/honeywall.conf
	cp /etc/honeywall.conf /etc/honeywall.conf.orig
	#	hw_startHoneywall
# Overkill but *much* more reliable and this is a one-time-thing
		/etc/init.d/hwdaemons restart
	echo "honeywall.conf found and loaded...from floppy" >> $LOG
fi

#handle ssh-keys
#checking for no keys in /tmp/roo/ssh-keys (means none on cd).

# User "roo" keys
mkdir -p /tmp/roo/ssh-keys >> $LOG 2>&1
echo "DIR /tmp/roo/ssh-keys created..." >> $LOG

mcopy -n a:/ssh-keys/* /tmp/roo/ssh-keys >> $LOG 2>&1
if [ $? -eq 1 ]; then
	echo "No roo SSH Keys found...on floppy" >> $LOG
	if [ `ls /tmp/roo/ssh-keys | wc -l ` -eq 0 ]; then
	    echo "No roo SSH Keys found...on CDROM" >> $LOG
           
  	else
		#found keys on cdrom
		echo "About to copy roo keys...from CDROM" >> $LOG
		mkdir -p /home/roo/.ssh	
		touch /home/roo/.ssh/authorized_keys
	        for key in `/bin/ls /tmp/roo/ssh-keys`; do 
			echo "About to cat /tmp/roo/ssh-keys/$key >> /home/roo/.ssh/authorized_keys" >> $LOG
			cat /tmp/roo/ssh-keys/$key >> /home/roo/.ssh/authorized_keys
		done
		chown roo:roo /home/roo/.ssh/authorized_keys
		chmod 0600 /home/roo/.ssh/authorized_keys
		echo "Done copying roo keys...from CDROM" >> $LOG
		echo "roo ssh key(s) appended to authorized_key file..." >> $LOG
	fi
else
	#found keys on floppy
	echo "About to copy roo keys...from Floppy" >> $LOG
	mkdir -p /home/roo/.ssh	
	touch /home/roo/.ssh/authorized_keys
        for key in `ls /tmp/roo/ssh-keys`; do 
		echo "About to cat /tmp/roo/ssh-keys/$key >> /home/roo/.ssh/authorized_keys" >>  $LOG
		cat /tmp/roo/ssh-keys/$key >> /home/roo/.ssh/authorized_keys
	done
	chown roo:roo /home/roo/.ssh/authorized_keys
	chmod 0600 /home/roo/.ssh/authorized_keys
	echo "Done copying roo keys...from Floppy"  >> $LOG
        echo "roo ssh key(s) appended to authorized_key file..." >> $LOG

fi

# User "root" keys
mkdir -p /tmp/roo/ssh-keys-root >> $LOG 2>&1
echo "DIR /tmp/roo/ssh-keys-root created..." >> $LOG

mcopy -n a:/ssh-keys-root/* /tmp/roo/ssh-keys-root >> $LOG 2>&1
if [ $? -eq 1 ]; then
	echo "No root SSH Keys found...on floppy" >> $LOG
	if [ `ls /tmp/roo/ssh-keys-root | wc -l ` -eq 0 ]; then
	    echo "No root SSH Keys found...on CDROM" >> $LOG
           
  	else
		#found keys on cdrom
		echo "About to copy root keys...from CDROM" >> $LOG
		mkdir -p /root/.ssh	
		touch /root/.ssh/authorized_keys
	        for key in `/bin/ls /tmp/roo/ssh-keys-root`; do 
			echo "About to cat /tmp/roo/ssh-keys-root/$key >> /root/.ssh/authorized_keys" >> $LOG
			cat /tmp/roo/ssh-keys-root/$key >> /root/.ssh/authorized_keys
		done
		chown root:root /root/.ssh/authorized_keys
		chmod 0600 /root/.ssh/authorized_keys
		echo "Done copying root keys...from CDROM" >> $LOG
		echo "root ssh key(s) appended to authorized_key file..." >> $LOG
	fi
else
	#found keys on floppy
	echo "About to copy root keys...from Floppy" >> $LOG
	mkdir -p /root/.ssh	
	touch /root/.ssh/authorized_keys
        for key in `ls /tmp/roo/ssh-keys-root`; do 
		echo "About to cat /tmp/roo/ssh-keys-root/$key >> /root/.ssh/authorized_keys" >>  $LOG
		cat /tmp/roo/ssh-keys-root/$key >> /root/.ssh/authorized_keys
	done
	chown root:root /root/.ssh/authorized_keys
	chmod 0600 /root/.ssh/authorized_keys
	echo "Done copying root keys...from Floppy"  >> $LOG
        echo "root ssh key(s) appended to authorized_key file..." >> $LOG

fi

# System keys
mkdir -p /tmp/roo/ssh-keys-system >> $LOG 2>&1
echo "DIR /tmp/roo/ssh-keys-system created..." >> $LOG

mcopy -n a:/ssh-keys-system/* /tmp/roo/ssh-keys-system >> $LOG 2>&1
if [ $? -eq 1 ]; then
	echo "No system SSH Keys found...on floppy" >> $LOG
	if [ `ls /tmp/roo/ssh-keys-system | wc -l ` -eq 0 ]; then
	    echo "No system SSH Keys found...on CDROM" >> $LOG
           
  	else
		#found keys on cdrom
		echo "About to copy system keys...from CDROM" >> $LOG
	        for key in `/bin/ls /tmp/roo/ssh-keys-system`; do 
		  if [ -f /etc/ssh/${key} ]; then
		     echo "Backing up /etc/ssh/${key} to /etc/ssh/${key}.roo_save" >> $LOG
		     cp /etc/ssh/${key} /etc/ssh/${key}.roo_save
		  fi
		  echo "About to copy /tmp/roo/ssh-keys-system/$key to /etc/ssh/" >> $LOG
		  if [ "$(echo ${key} | grep -c "\.pub$")" -gt 0 ]; then
			/usr/bin/install -o root -g root -m 0644 /tmp/roo/ssh-keys-system/$key /etc/ssh/ >> $LOG 2>&1
		  else
			/usr/bin/install -o root -g root -m 0600 /tmp/roo/ssh-keys-system/$key /etc/ssh/ >> $LOG 2>&1
		  fi
		done
		echo "Done copying system keys...from CDROM" >> $LOG
	fi
else
	#found keys on floppy
	echo "About to copy system keys...from Floppy" >> $LOG
        for key in `/bin/ls /tmp/roo/ssh-keys-system`; do 
	  if [ -f /etc/ssh/${key} ]; then
	     echo "Backing up /etc/ssh/${key} to /etc/ssh/${key}.roo_save" >> $LOG
	     cp /etc/ssh/${key} /etc/ssh/${key}.roo_save
	  fi
	  echo "About to copy /tmp/roo/ssh-keys-system/$key to /etc/ssh/" >> $LOG
	  if [ "$(echo ${key} | grep -c "\.pub$")" -gt 0 ]; then
		/usr/bin/install -o root -g root -m 0644 /tmp/roo/ssh-keys-system/$key /etc/ssh/ >> $LOG 2>&1
	  else
		/usr/bin/install -o root -g root -m 0600 /tmp/roo/ssh-keys-system/$key /etc/ssh/ >> $LOG 2>&1
	  fi
	done
	echo "Done copying system keys...from floppy" >> $LOG

fi

#################################################
# Call the user's custom.sh (from worm hole)...
echo "Checking for user's custom.sh..." >> $LOG
/tmp/roo/custom.sh >> $LOG 2>&1


#cleanup
echo "Cleaning up temp keys..." >> $LOG
/bin/rm -rf /tmp/roo/ >> $LOG 2>&1

