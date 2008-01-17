#!/usr/bin/perl
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

#----- purgeDB.pl
#-----
#----- removed data from db which is older than storage limit defined in HwDBDAYS
#-----
#-----
#----- Version: $Id: purgeDB.pl 4555 2006-10-17 03:12:45Z esammons $
#-----
#----- Authors: Camilo Viecco <cviecco@indiana.edu>
#-----

use strict;
use 5.004;
use POSIX;
#use Walleye::Login;
use DBI;
use DBD::mysql;

# Allows user to enter a command line argument for dbdays
my $COMMANDARG = $ARGV[0];

my $CONFDIR = "/hw/conf";
my $LOGDIR = "/var/log/pcap";

# sbuchan - I commented this out.  This is not being used as a global variable
#my $dbdays = "$CONFDIR/HwDBDAYS";

my $whitelist;

my $count = 0;
my $file_lines = ();

my $database="walleye_0_3";
my $dbuser="roo";
my $dbpasswd="honey";

sub old_update($$$){
   my ($select_statement,$update_statement,$dbh)=@_;
   my $sth;
   my $sth2;  
   my $ident1;
   my $ident2;
   my $row_limit=1000;
   my $num_selected=$row_limit*2;
   my $iter=0;
   my $sth;
   my $base;


   #$select_statement .= " LIMIT 1000";
   
   
   while($num_selected>=$row_limit){
      $base=$iter*$row_limit;
      $sth="$select_statement  LIMIT $base,$row_limit";
      #$sth=$dbh->prepare($select_statement) or die "cannot prepare query". $sth->errstr;
      $sth=$dbh->prepare($select_statement) or die "cannot prepare query". $sth->errstr; 
      $sth->execute() or die "Cannot execute statement $select_statement\n".$sth->errstr;
      $num_selected=$sth->rows;
      $sth->bind_columns(undef,\$ident1,\$ident2);

      $sth2=$dbh->prepare($update_statement) or die "cannot prepare query $update_statement\n".$sth2->errstr;
      while($sth->fetch){
          $sth2->bind_param(1,$ident1,DBI::SQL_INTEGER);
          $sth2->bind_param(2,$ident2,DBI::SQL_INTEGER);
          $sth2->execute() or die "cannot execute statement $update_statement\n".$sth2->errstr;
      }
      $sth2->finish;
      $iter++;
   }
   $sth->finish;
   
}


sub main(){

   my $dbdays;
   #my $dbdays= `cat $CONFDIR/HwDBDAYS`

   # Check to see if user entered a valid number of days on command line
   if ($COMMANDARG =~ /\D+?/) {
       $dbdays= `cat $CONFDIR/HwDBDAYS`;
   } else {
       $dbdays = $COMMANDARG;
   }

   my $limit=time()-3600*24*$dbdays;
   my $directory;
   my $subdir;
   my $line;
   my $dbh = DBI->connect("DBI:mysql:database=$database",$dbuser,$dbpasswd) or die "cannot connect to database\n";

   my $sth;
   my $numselected;
   my $sth2;
   my $sql;
   my $sensor_id;
   my $ids_id;

   #print("limit=$limit \n");


   #deletion is made on two steps
   #step 1 marks what data is to be deleted
   #step 2 acutally deletes data...

   #---------
   #step1.a mark ids data based on argus...
   #$sth=$dbh->prepare("UPDATE ids,argus SET ids.to_be_deleted=1 WHERE ids.argus_id=argus.argus_id AND argus.end_sec<$limit") or die "cannot prepare statement for ids". $dbh->errstr;
   #$sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("ids marked\n");
   #$sth->finish;
   old_update("SELECT ids.sensor_id,ids_id FROM ids,argus WHERE argus.sensor_id=ids.sensor_id AND ids.argus_id=argus.argus_id AND argus.end_sec<$limit",
              "UPDATE  ids SET to_be_deleted=1  WHERE sensor_id=? and ids_id=?",
               $dbh);

   #step1.b mark process tree based on process...
   #$sth=$dbh->prepare("UPDATE process_tree,process SET process_tree.to_be_deleted=1 WHERE (child_process=process_id OR parent_process=process_id) AND pcap_time_max<$limit") or die "cannot prepare statement for ids". $dbh->errstr;
   #$sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("ids done\n");
   #$sth->finish;
   old_update("SELECT process_tree.sensor_id,child_process FROM process_tree,process  WHERE (child_process=process_id OR parent_process=process_id) AND pcap_time_max<$limit",
              "UPDATE process_tree SET to_be_deleted=1 WHERE sensor_id=? and child_process=?",
               $dbh);
 
   #step1.c mark process to com  ->should it be on the same table?
   #$sth=$dbh->prepare("UPDATE process_to_com,process SET process_to_com.to_be_deleted=1 WHERE process_to_com.process_id=process.process_id AND pcap_time_max<$limit") or die "cannot prepare statement for ids". $dbh->errstr;
   #$sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("ids done\n");
   #$sth->finish;
 old_update("SELECT process_to_com.sensor_id,process_to_com.process_id FROM process_to_com,process  WHERE process_to_com.sensor_id=process.sensor_id AND process_to_com.process_id=process.process_id AND pcap_time_max<$limit",
              "UPDATE process_to_com SET to_be_deleted=1 WHERE sensor_id=? and process_id=?",
               $dbh);

   #step1.d mark sys_read 
   #$sth=$dbh->prepare("UPDATE sys_read,process SET sys_read.to_be_deleted=1 WHERE sys_read.process_id=process.process_id AND pcap_time_max<$limit") or die "cannot prepare statement for ids". $dbh->errstr;
   #$sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("ids done\n");
   #$sth->finish;
 old_update("SELECT sys_read.sensor_id,sys_read_id  FROM sys_read,process WHERE sys_read.sensor_id=process.sensor_id AND sys_read.process_id=process.process_id AND pcap_time_max<$limit",
              "UPDATE sys_read SET to_be_deleted=1 WHERE sensor_id=? and sys_read_id=?",
               $dbh);



   #step1.e mark sys_open 
   #$sth=$dbh->prepare("UPDATE sys_open,process SET sys_open.to_be_deleted=1 WHERE sys_open.process_id=process.process_id AND pcap_time_max<$limit") or die "cannot prepare statement for ids". $dbh->errstr;
   #$sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("ids done\n");
   #$sth->finish;
  old_update("SELECT sys_open.sensor_id,sys_open_id  FROM sys_open,process WHERE sys_open.sensor_id=process.sensor_id AND sys_open.process_id=process.process_id AND pcap_time_max<$limit",
              "UPDATE sys_open SET to_be_deleted=1 WHERE sensor_id=? and sys_open_id=?",
               $dbh);



   #step1.f mark sys_socket  
   #$sth=$dbh->prepare("UPDATE sys_socket,process SET sys_socket.to_be_deleted=1 WHERE sys_socket.process_id=process.process_id AND pcap_time_max<$limit") or die "cannot prepare statement for ids". $dbh->errstr;
   #$sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("sock_ marked done\n");
   #$sth->finish;
   old_update("SELECT sys_socket.sensor_id,sys_socket_id  FROM sys_socket,process WHERE sys_socket.sensor_id=process.sensor_id AND sys_socket.process_id=process.process_id AND pcap_time_max<$limit",
              "UPDATE sys_socket SET to_be_deleted=1 WHERE sensor_id=? and sys_socket_id=?",
               $dbh);



   #--------------------
   # now step 2 delete...
   # 

   # do argus 
   $sth=$dbh->prepare("DELETE FROM argus WHERE end_sec<$limit") or die "cannot prepare statement for argus". $dbh->errstr;
   $sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("argus done\n");
   $sth->finish;

   # do process
   $sth=$dbh->prepare("DELETE FROM process WHERE pcap_time_max<$limit") or die "cannot prepare statement for argus". $dbh->errstr;
   $sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("process done\n");
   $sth->finish;

   #do ids
   $sth=$dbh->prepare("DELETE FROM ids WHERE to_be_deleted=1") or die "cannot prepare statement for argus". $dbh->errstr;
   $sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("ids done\n");
   $sth->finish;

   #do process_tree
   $sth=$dbh->prepare("DELETE FROM process_tree WHERE to_be_deleted=1") or die "cannot prepare statement for argus". $dbh->errstr;
   $sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("process_tree done\n");
   $sth->finish;

   #do process_to_com
   $sth=$dbh->prepare("DELETE FROM process_to_com WHERE to_be_deleted=1") or die "cannot prepare statement for argus". $dbh->errstr;
   $sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("process_to_com  done\n");
   $sth->finish;

   #do sys_open
   $sth=$dbh->prepare("DELETE FROM sys_open WHERE to_be_deleted=1") or die "cannot prepare statement for argus". $dbh->errstr;
   $sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("sys_open done\n");
   $sth->finish;  

   #do sys_read
   $sth=$dbh->prepare("DELETE FROM sys_read WHERE to_be_deleted=1") or die "cannot prepare statement for argus". $dbh->errstr;
   $sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("sys_read done\n");
   $sth->finish;

    #do socket
   $sth=$dbh->prepare("DELETE FROM sys_socket WHERE to_be_deleted=1") or die "cannot prepare statement for argus". $dbh->errstr;
   $sth->execute() or die "cannot execute statement".$sth->errstr;
   #print("sys_socket done\n");
   $sth->finish;




   #print "$limit  $dbdays\n";
   $dbh->disconnect;
}

main();

