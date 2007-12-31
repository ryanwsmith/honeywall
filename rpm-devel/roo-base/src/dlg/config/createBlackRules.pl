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
# $Id: createBlackRules.pl 4698 2006-11-03 18:08:36Z esammons $
#
# PURPOSE: To create a set of "black" snort rules (drop and not log) 
#          based on the ips defined within HwFWBLACK

$CONFDIR = "/hw/conf";
$rulefile = "/etc/snort/rules/blacklist.rules";
$blackListVar = "$CONFDIR/HwFWBLACK";
$blacklist;

$count = 0;
@file_lines = ();

#Read from HwFWBLACK.
open(FILE, $blackListVar) || die "Could not open $blackListVar: $!";
while (<FILE>) {
   #first, let's remove any white space that may be at the end of the line.
   s/\s+$//;

   #strip trailing comments
   s|\s+#.*||;

   #Next, let's remove any newlines
   chomp;

   #print "$_\n";
   $blacklist = $_;
}
close FILE;

#Read from blacklist.
open(FILE, $blacklist) || die "Could not open $blacklist: $!";
while (<FILE>) {
   #first, let's remove leading and trailing any white space
   s/\s+$//;
   s/^\s+//;

   #Next if comment
   next if m|^\s*#|;

   #strip trailing comments
   s|\s+#.*||;

   #Next if blank line (Prevents "pass ip any <> any any) YIKES!!!
   next if /^(\s)*$/;

   #Next, let's remove any newlines
   chomp;

   #print "$_\n";
   push @file_lines, $_;
}
close FILE;

#Write new file
open(FILE, ">$rulefile") || die "Could not open $rulefile: $!";

foreach $item (@file_lines) {
   print FILE "pass ip $item any <> any any\n";
}

close(FILE);
exit(0);
