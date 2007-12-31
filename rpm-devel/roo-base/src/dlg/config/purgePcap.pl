#!/usr/bin/perl

#
#
# Copyright (C) 2005 The Trustees of Indiana University.  All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
#
#
# $Id: purgePcap.pl 4567 2006-10-18 17:03:58Z esammons $
#
# Purpose: Removes old pcap files based on X old days
#
# Author: Camilo H. Viecco <cviecco@indiana.edu>
#


use strict;
use 5.004;
use POSIX;

use File::Find;

# Allows user to enter a command line argument for dbdays
my $COMMANDARG = $ARGV[0];

my $CONFDIR = "/hw/conf";
my $LOGDIR = "/var/log/pcap";

# sbuchan - I commented this out.  This is not being used as a global variable
#my $pcapdays = "$CONFDIR/HwPCAPDAYS";

my $whitelist;

my $count = 0;
my $file_lines = ();

# Recursively search the directory for pcap files or dirs.
sub find_rules_files {
        my($dir) = @_;
        my @dirs;
        $dirs[0]= "$dir";
        my $filename;
        my $filepath;

    my $numDirs = 0;

        find sub {
                return unless -d;
                $filename = $_;
                $filepath = $File::Find::name;
        if ($filepath ne $dir) {
            $numDirs += 1;
        }
                }, @dirs;

    return $numDirs;

}

sub main(){

  my $pcapdays;
  #my $pcapdays= `cat $CONFDIR/HwPCAPDAYS`;

   # Check to see if user entered a valid number of days on command line
   if ($COMMANDARG =~ /\D+?/) {
       $pcapdays= `cat $CONFDIR/HwPCAPDAYS`;
   } else {
       $pcapdays = $COMMANDARG;
   }

   my $limit=time()-3600*24*$pcapdays;
   my $directory;
   my $subdir;
   my $line;

   #my $pcapdays= `cat $CONFDIR/HwPCAPDAYS`;

   open($directory,"ls $LOGDIR|");
   while($subdir=<$directory>){
	chomp($subdir);
	if($subdir<$limit){
		$subdir=$LOGDIR."/".$subdir;
		#print "will delete '$subdir'\n";
		system("rm -rf $subdir");
	}
   }
   close($directory);

   #print "$limit  $pcapdays\n";
}

main();

# Check to make sure there is at least one directory in /var/log/pcap

my $dirs = find_rules_files("/var/log/pcap");


if ($dirs == 0) {
   my $cmd = "/etc/init.d/hwdaemons log_cleanout_restart";
   my $status = system("$cmd");
   die "Could not run process: $cmd $?" unless $status == 0;

}
    
