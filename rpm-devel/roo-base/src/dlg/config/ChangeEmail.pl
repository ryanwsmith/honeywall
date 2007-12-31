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
# $Id: ChangeEmail.pl 1974 2005-08-13 01:43:35Z patrick $
#
# PURPOSE: To change the email in swatchrc without affecting the rest
#          of the file.  The email address will be replaced by the 
#          contents of HwALERT_EMAIL.
#
# (This file duplicates funcationality in Email.pl.  If you change
# this file, make sure you change the other as well.)

$CONFDIR = "/hw/conf";
$file = "/etc/swatchrc";
$monitrc = "/etc/monitrc";
$efile = "$CONFDIR/HwALERT_EMAIL";

@file_lines = ();
@monit_lines = ();

#Read email address from HwALERT_EMAIL.
open(FILE, $efile) || die "Could not open $efile: $!";
while (<FILE>) {
   #first, let's remove any white space that may be at the end of the email.
   s/\s+$//;
   #Next, let's remove any newlines
   chomp;
   $mail_address = $_;
}
close FILE;

#Open swatchrc file
open(FILE, "<$file") || die "Could not open $file: $!";

while ($line = <FILE>) {
   if ($line =~ m/mail=/) {

      #This assumes the email line has the following format:
      #mail=${HwALERT_EMAIL},subject=------ ALERT! OUTBOUND TCP --------
      #We will use the comma (,) as a delimiter
      @tokens = split(/,/, $line); 
      @mail = split(/=/, $tokens[0]);
      $mail[1] = $mail_address;
      $line = "mail=" . $mail[1] . "," . $tokens[1];
      #print $line;
   }
   push @file_lines, $line;
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
   push @monit_lines, $line;
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

#Write new monitrc file
$count = $#monit_lines + 1;
$cur_count = 0;
                                                                                
open(FILE, ">$monitrc") || die "Could not open $monitrc: $!";
                                                                                
while ($count) {
   print FILE $monit_lines[$cur_count];
   #print "Adding $monit_lines[$cur_count]\n";
   $count--;
   $cur_count++;
}
                                                                                
close(FILE);
exit(0);
