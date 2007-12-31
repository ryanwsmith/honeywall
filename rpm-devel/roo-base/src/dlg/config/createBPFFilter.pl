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
# $Id: createBPFFilter.pl 4698 2006-11-03 18:08:36Z esammons $
#
# PURPOSE: To create a set of bpf filter that will ignore the ips in the 
#          black and white lists.

$CONFDIR = "/hw/conf";
$bpffile = "/etc/snort/bpffilter.txt";
$whiteListVar = "$CONFDIR/HwFWWHITE";
$whitelist;
$blackListVar = "$CONFDIR/HwFWBLACK";
$blacklist;

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

#Read from whitelist.
open(FILE, $whitelist) || die "Could not open $whitelist: $!";
while (<FILE>) {
   #first, let's remove leading and trailing any white space
   s/\s+$//;
   s/^\s+//;

   #Next if comment
   next if m|^\s*#|;

   #Next if blank line
   next if m|^\s*$|;

   #strip trailing comments
   s|\s+#.*||;

   #Next, let's remove any newlines
   chomp;

   #print "$_\n";
   push @file_lines, $_;
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

   #Next if blank line
   next if m|^\s*$|;

   #strip trailing comments
   s|\s+#.*||;

   #Next, let's remove any newlines
   chomp;

   #print "$_\n";
   push @file_lines, $_;
}
close FILE;

$curcount = 0;

#Write new file
open(FILE, ">$bpffile") || die "Could not open $bpffile: $!";

if ( $#file_lines lt 0 )
{
   print FILE "";
}
else
{
   print FILE "not (\n";
   foreach $item (@file_lines) {
      # In case we put a network (192.168.0.0/24)
      if ($item =~ m/\//)
      {
         print FILE "net $item";
      }
      else
      {
         print FILE "host $item";
      }
      if ($cur_count < $#file_lines)
      {
         print FILE " or";
      }
      $cur_count++;
      print FILE "\n";
   }
   print FILE ")";
}
close(FILE);
exit(0);
