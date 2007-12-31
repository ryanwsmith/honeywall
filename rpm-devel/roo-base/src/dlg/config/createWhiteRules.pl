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
# $Id: createWhiteRules.pl 4698 2006-11-03 18:08:36Z esammons $
#
# PURPOSE: To create a set of "white" snort rules (accept and not log) 
#          based on the ips defined within HwFWWHITE

$CONFDIR = "/hw/conf";
$rulefile = "/etc/snort/rules/whitelist.rules";
$whiteListVar = "$CONFDIR/HwFWWHITE";
$whitelist;

$count = 0;
@file_lines = ();

#Read from HwFWWHITE.
open(FILE, $whiteListVar) || die "Could not open $whiteListVar: $!";
while (<FILE>) {
   #first, let's remove any white space that may be at the end of the line.
   s/\s+$//;

   #strip trailing comments
   s|\s+#.*||;

   #Next, let's remove any newlines
   chomp;

   #print "$_\n";
   $whitelist = $_;
}
close FILE;

#Read from whitelist.
open(FILE, $whitelist) || die "Could not open $whitelist: $!";
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
