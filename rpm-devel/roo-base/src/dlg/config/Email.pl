#!/usr/bin/perl
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
# $Id: Email.pl 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: Changes the email address in /etc/swatchrc and Hw_ALERT_EMAIL to the
#          one given by the user.
#
# (This file duplicates funcationality in ChangeEmail.pl.  If you change
# this file, make sure you change the other as well.)

$CONFDIR = "/hw/conf";
$file = "/etc/swatchrc";
$monitrc = "/etc/monitrc";
$oldemail = "email";
$varfile = "$CONFDIR/HwALERT_EMAIL";
@file_lines = ();
@monit_lines = ();

if ( (@ARGV) && ($#ARGV eq 0) ) {

   $mail_address = $ARGV[0];

   #Read old email.  If not one, use default "email"
   open(CONF, $varfile);
   while ($line = <CONF>) {
      chomp;
      $oldemail = $line;
   }
   close CONF;

   #Write new email to file.
   open(CONF, ">$varfile");
   print CONF $mail_address;
   close(CONF);

   #Open swatchrc file
   open(FILE, "<$file") || die "Could not open $file: $!";

   while ($line = <FILE>) {
      if ($line =~ m/mail=$oldemail/) {
         $line =~ s/mail=$oldemail/mail=$mail_address/;
         #print "The new one: $line\n";
      } elsif ($line =~ m/mail=email/) {
         $line =~ s/mail=email/mail=$mail_address/;
      }
      push @file_lines, $line;
   }

   close(FILE);

   $count = $#file_lines + 1;
   $cur_count = 0;

   #Write new file
   open(FILE, ">$file") || die "Could not open $file: $!";

   while ($count) {
      print FILE $file_lines[$cur_count];
      #print "Adding $file_lines[$cur_count]\n";
      $count--;
      $cur_count++;
   }

   close(FILE);

   #Open monitrc file
   open(FILE, "<$monitrc") || die "Could not open $monitrc: $!";

   while ($line = <FILE>) {
      # Look for, and edit in place, lines that look like
      # the following:
      #	alert root@localhost

      if ($line =~ m|([#\s]*alert\s*)(\S*)|) {
         #This replaces any line that contains alert 
         $line = "$1 $mail_address\n";
         #print $line;
      }
      #print "The new one: $line\n";
      push @monit_lines, $line;
   }

   close(FILE);

   $count = $#monit_lines + 1;
   $cur_count = 0;

   #Write new file
   open(FILE, ">$monitrc") || die "Could not open $monitrc: $!";

   while ($count) {
      print FILE $monit_lines[$cur_count];
      #print "Adding $monit_lines[$cur_count]\n";
      $count--;
      $cur_count++;
   }

   close(FILE);
   exit(0);
} else {
   print "Usage: email.pl <alert email>\n";
   exit(1);
}
