#!/usr/bin/perl -T

# (C) 2005 The Trustees of Indiana University.  All rights reserved.
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


#----- Walleye:  Honeywall Data Analysis Interface
#-----
#----- Version:  $Id: walleye.pl 2514 2005-12-27 21:26:21Z sbuchan $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  
#-----


use 5.004;
use strict;

use Socket;

use DBI;
use DBI qw(:sql_types);
use DBD::mysql;
use Date::Manip;

use HTML::Table;
use HTML::Entities;
use CGI qw/:standard/;

use POSIX;
use Date::Format;


#---- load up the walleye modules
use Walleye::Util;
use Walleye::Aggregate_flow;
use Walleye::Connection_table;
use Walleye::Host;
use Walleye::Flow;
use Walleye::Process_tree;
use Walleye::Process;
use Walleye::Admin;

use Walleye::Login;



sub gen_title_bar{
    my $title = shift;
    
    my $nav = new HTML::Table(
			      -border=>0,
			      -class=>'nav',
			      );
    
    $nav->addRow(
		 "",
		 "",
		 "",
		 "<h3>$title</h3>",
		 scalar gmtime,
		 "",
		    );

    $nav->setCellColSpan(1,1,3);
    $nav->setCellColSpan(1,5,2);
    $nav->setCellClass(1,1,"nav_title");
    $nav->setCellClass(1,4,"nav_title");
    $nav->setCellClass(1,5,"nav_title");

    $nav->addRow(
		 "",
		 "",
		 "",
		 "",
		 "",
		 ""
		    );
   
    $nav->setCellClass(2,1,"nav_blank");
    $nav->setCellClass(2,2,"nav_blank");
    $nav->setCellClass(2,3,"nav_blank");
    $nav->setCellClass(2,4,"nav_blank_big");
    $nav->setCellClass(2,5,"nav_blank");
    $nav->setCellClass(2,6,"nav_blank");
	
    $nav->setRowHeight(2,25);
	
    return $nav->getTable;
}


#-------------------------------------------------
sub gen_nav_bar{
    my $cur  = shift;
    my $role = shift;
    my $time = time2str('%a %b %d %X %Y %Z', time);
    
    my $nav = new HTML::Table(
			      -border=>0,
			      -class=>'nav',
			      );

    $nav->addRow(
		 "",
		 "",
		 "<center><h3>Walleye: Honeywall Web Interface </h3></center>",
		 "",
		 "<center>".$time."</br>Logged in as $role</center>",
		 "",
	         ""
		    );

    $nav->setCellColSpan(1,1,2);
    $nav->setCellColSpan(1,3,2);
    $nav->setCellColSpan(1,5,3);
    $nav->setCellClass(1,1,"nav_title");
    $nav->setCellClass(1,3,"nav_title");
    $nav->setCellClass(1,5,"nav_title");


    
    $nav->addRow(
		 "<a class=\"nav\" href=\"?act=overview\">Data Analysis</a>",
		 "<a class=\"nav\" href=\"admin\">System Admin</a>",
		 "<a class=\"nav\" href=\"admin/customizeIso.pl\">Customize CD-ROM</a>",
         "<a class=\"nav\" href=\"logout.pl\">Logout</a>",
		 "",
	     ""
		 );
  
    $nav->setCellClass(2,1,"nav");
    $nav->setCellClass(2,2,"nav");
	$nav->setCellClass(2,3,"nav");
	$nav->setCellClass(2,4,"nav");
    

    if($cur > 0 ){
	$nav->setCellClass(2,$cur,"nav_cur")
    }
	
    return $nav->getTable;
}














sub gen_sensor_detail{
    my $sensor = shift;
    my $ref;
    my $foo;
    my $query;
    my $pq;
    
    my $report_duration  = 24;


    my $timespec = "st=".(time()-(3600 * $report_duration)).";et=".time();
			  
    my $table = new HTML::Table(
				-padding=>1,
				-border=>0,
				-class=>"summary",
				);


    $table->addRow("Honeywall Details for $sensor");
  
    #----- get basic info about the sensor
    $query = "select * from sensor where sensor_id = ?";
    $pq    = $Walleye::Util::dbh->prepare($query);
    $pq->execute($sensor);
    $ref = $pq->fetchrow_arrayref;

    $table->addRow(
		   "Sensor ID:",
		   $$ref[0],
		   "Sensor Name:",
		   $$ref[4]
		   );

    $table->addRow(
		   "Install Date:",
		   scalar(gmtime($$ref[1])),
		   "Last Update:",
		   scalar(gmtime($$ref[2]))
		   );

    $table->addRow(
		   "State:",
		   $$ref[3],
		   "",
		   ""
		   );
   
    $table->addRow(
		   "Country:",
		   $$ref[6],
		   "Timezone:",
		   $$ref[5]
		   );
   
    $table->addRow(
		   "Latitude:",
		   $$ref[7],
		   "Longitude:",
		   $$ref[8]
		   );
 
    $table->addRow(
		   "Network Type:",
		   $$ref[10],
		   "",
		   ""
		   );

    $table->addRow(
		   "Notes:",
		   $$ref[9]
		   );

    $table->addRow("Activity Report");
    
    $table->setColClass(1,"sum_head_l");
    $table->setColClass(2,"sum_body");
    $table->setColClass(3,"sum_head_l");
    $table->setColClass(4,"sum_body");

    
    $table->setCellClass(1,1,"sum_h");
    $table->setCellColSpan(1,1,4);
    $table->setCellColSpan(8,2,3);
    $table->setCellColSpan(9,1,4);
    $table->setCellClass(9,1,"sum_head_t");
    


    $query  = "select src_ip, FORMAT(count(argus.argus_id),0), FORMAT(count(ids.ids_id),0), FORMAT(count(sys_socket.sys_socket_id),0), count(argus.argus_id), count(ids.ids_id) from argus";
    $query .= " left join ids on ids.argus_id = argus.argus_id  and argus.sensor_id = ids.sensor_id";
    $query .= " left join sys_socket on sys_socket.argus_id = argus.argus_id and  argus.sensor_id = sys_socket.sensor_id";
    $query .= " where  argus.sensor_id = ? ";
    $query .= " and local = ?";
    $query .= " and argus.start_sec > UNIX_TIMESTAMP(DATE_SUB(now(), INTERVAL ? HOUR  )) ";
    $query .= " group by src_ip order by 6 desc, 5 desc   limit 10";


    my $sipq = $Walleye::Util::dbh->prepare($query);

    $sipq->execute($sensor,1,$report_duration);

    my $rtable = new HTML::Table(
				 -border=>0,
			   
				 );
    my $ltable = new HTML::Table(
				 -border=>0,
			       
				 );


    $rtable->addRow("Top 10 Honeypots");
   
 

    $ref = $sipq->fetchall_arrayref();
    my $col1;
    my $col2;

    my $x = 3;
    $rtable->addRow("Flags","Host","Connections","IDS events");
    foreach $foo(@$ref){
	$col1 = "";
	$col2 = "<a href=\"?act=hd;ip=".$$foo[0]."\">".inet_ntoa(pack('N',$$foo[0]))."</a>";
	if($$foo[3] > 0){
	    #--- this host is running sebek
	    $col1 = "<B>Sebeked</B>";
	    $col2 = "<a class=\"green\" href=\"?act=hd;ip=".$$foo[0]."\">".inet_ntoa(pack('N',$$foo[0]))."</a>";
	}
	$rtable->addRow(
			$col1,
			$col2,
			"<a href=\"?act=ct;".$timespec.";ip=".$$foo[0]."\">$$foo[1]</a>",
			"<a href=\"?act=ct;".$timespec.";ip=".$$foo[0].";ids=1\">$$foo[2]</a>"
			);

	if($$foo[3] > 0){
	    $rtable->setCellClass($x,1,"sum_hi");
	    $rtable->setCellClass($x,2,"sum_hi");
	    $rtable->setCellClass($x,3,"sum_hi");
	    $rtable->setCellClass($x,4,"sum_hi");
	}else{
	    $rtable->setCellClass($x,1,"sum_body");
	    $rtable->setCellClass($x,2,"sum_body");
	    $rtable->setCellClass($x,3,"sum_body");
	    $rtable->setCellClass($x,4,"sum_body");
	}
	
	$x++;
    }

  
    $rtable->setCellClass(1,1,"sum_head_t");
    $rtable->setCellClass(2,1,"sum_head_t");
    $rtable->setCellClass(2,2,"sum_head_t");
    $rtable->setCellClass(2,3,"sum_head_t");
    $rtable->setCellClass(2,4,"sum_head_t");

    $rtable->setCellColSpan(1,1,4);
   
    $sipq->execute($sensor,0,$report_duration);

    $ltable->addRow("Top 10 Remote Hosts");
    $ltable->addRow("Host","Connections","IDS events");

    $ref = $sipq->fetchall_arrayref();
    foreach $foo(@$ref){
	$ltable->addRow(
			"<a href=\"?act=hd;ip=".$$foo[0]."\">".inet_ntoa(pack('N',$$foo[0]))."</a>",
			"<a href=\"?act=ct;".$timespec.";ip=".$$foo[0]."\">$$foo[1]</a>",
			"<a href=\"?act=ct;".$timespec.";ip=".$$foo[0].";ids=1\">$$foo[2]</a>"
			);
    }

    $ltable->setColClass(1,"sum_body");
    $ltable->setColClass(2,"sum_body");
    $ltable->setColClass(3,"sum_body");
  
    $ltable->setCellClass(1,1,"sum_head_t");
    $ltable->setCellColSpan(1,1,3);
    
    $ltable->setCellClass(1,1,"sum_head_t");
    $ltable->setCellClass(2,1,"sum_head_t");
    $ltable->setCellClass(2,2,"sum_head_t");
    $ltable->setCellClass(2,3,"sum_head_t");
    
    $table->addRow($rtable->getTable(),"",$ltable->getTable(),"");
    $table->setCellColSpan(10,1,2);
    $table->setCellColSpan(10,3,2);

    #--- port activity

    $query  = "select src_port, FORMAT(count(argus.argus_id),0), FORMAT(count(ids.ids_id),0), count(argus.argus_id), count(ids.ids_id)from argus";
    $query .= " left join ids on ids.argus_id = argus.argus_id  and argus.sensor_id = ids.sensor_id";
    $query .= " where  argus.sensor_id = ? ";
    $query .= " and argus.start_sec > UNIX_TIMESTAMP(DATE_SUB(now(), INTERVAL ? HOUR  )) ";
    $query .= " group by src_port order by 5 desc, 4 desc   limit 10";


    $sipq = $Walleye::Util::dbh->prepare($query);

    $sipq->execute($sensor,$report_duration);

    $rtable = new HTML::Table(
				 -border=>0,
			   
				 );
   $ltable = new HTML::Table(
				 -border=>0,
			       
				 );


    $rtable->addRow("Top 10 Source Ports");
   
 

    $ref = $sipq->fetchall_arrayref();
    my $col1;
    my $col2;

    my $x = 3;
    $rtable->addRow("Port","Connections","IDS events");
    foreach $foo(@$ref){

	$rtable->addRow(
			"$$foo[0]",
			"<a href=\"?act=ct;".$timespec.";port=".$$foo[0]."\">$$foo[1]</a>",
			"<a href=\"?act=ct;".$timespec.";port=".$$foo[0].";ids=1\">$$foo[2]</a>"
			);

	$rtable->setCellClass($x,1,"sum_body");
	$rtable->setCellClass($x,2,"sum_body");
	$rtable->setCellClass($x,3,"sum_body");
	
	$x++;
    }

  
    $rtable->setCellClass(1,1,"sum_head_t");
    $rtable->setCellClass(2,1,"sum_head_t");
    $rtable->setCellClass(2,2,"sum_head_t");
    $rtable->setCellClass(2,3,"sum_head_t");

    $rtable->setCellColSpan(1,1,3);
   
    $query  = "select dst_port, FORMAT(count(argus.argus_id),0), FORMAT(count(ids.ids_id),0), count(argus.argus_id), count(ids.ids_id) from argus";
    $query .= " left join ids on ids.argus_id = argus.argus_id  and argus.sensor_id = ids.sensor_id";
    $query .= " where  argus.sensor_id = ? ";
    $query .= " and argus.start_sec > UNIX_TIMESTAMP(DATE_SUB(now(), INTERVAL ? HOUR  )) ";
    $query .= " group by dst_port order by 5 desc, 4 desc   limit 10";

    $sipq = $Walleye::Util::dbh->prepare($query);


    $sipq->execute($sensor,$report_duration);

    $ltable->addRow("Top 10 Destination Ports");
    $ltable->addRow("Port","Connections","IDS events");

    $ref = $sipq->fetchall_arrayref();
    foreach $foo(@$ref){
	$ltable->addRow(
			$$foo[0],
			"<a href=\"?act=ct;".$timespec.";port=".$$foo[0]."\">$$foo[1]</a>",
			"<a href=\"?act=ct;".$timespec.";port=".$$foo[0].";ids=1\">$$foo[2]</a>"
			);
    }

    $ltable->setColClass(1,"sum_body");
    $ltable->setColClass(2,"sum_body");
    $ltable->setColClass(3,"sum_body");
  
    $ltable->setCellClass(1,1,"sum_head_t");
    $ltable->setCellColSpan(1,1,3);
    
    $ltable->setCellClass(1,1,"sum_head_t");
    $ltable->setCellClass(2,1,"sum_head_t");
    $ltable->setCellClass(2,2,"sum_head_t");
    $ltable->setCellClass(2,3,"sum_head_t");
    
    $table->addRow($rtable->getTable(),"",$ltable->getTable(),"");
    $table->setCellColSpan(11,1,2);
    $table->setCellColSpan(11,3,2);

   
    return $table->getTable;
}


#------ gen_overview creates the honeywall overview page
sub gen_overview{
   
    my $ref;
   
    my %lut;
    
    my $hp;
    my $foo;

    #----- get input -------------
    my $sensor_detail = param('sensor');

    #----- get list of online sensors
    my $query  = "select sensor.sensor_id, name, sensor.last_upd_sec, sensor.install_sec  from sensor ";
      $query .=  " where state = \"online\" ";

    my $sql    = $Walleye::Util::dbh->prepare($query);
    $sql->execute();
    $ref = $sql->fetchall_arrayref();

    foreach $foo(@$ref){
	$lut{$$foo[0]}{"sensor"} = $$foo[1];
	$lut{$$foo[0]}{"last_update"} = $$foo[2];
	$lut{$$foo[0]}{"created"} = $$foo[3];
    }

    

    $hp = Walleye::Util::array_to_in($ref,0);
  
    
    $query   = "select argus.sensor_id , FORMAT(count(argus.argus_id),0), FORMAT(count(ids.ids_id),0) ";
    $query  .= "from argus ";
    $query  .= "left join ids on ids.sensor_id = argus.sensor_id and ids.argus_id = argus.argus_id ";
    $query  .= "where argus.sensor_id in $hp and local = ? ";
    $query  .= "and src_bytes > 0 and dst_bytes > 0 ";
    $query  .= "and end_sec > UNIX_TIMESTAMP(DATE_SUB(now(), INTERVAL ? HOUR) ) ";
    $query  .= " group by sensor_id";

    $sql  = $Walleye::Util::dbh->prepare($query);
    
    $query   = "select argus.sensor_id , FORMAT(count(argus.argus_id),0), FORMAT(count(ids.ids_id),0) ";
    $query  .= "from argus ";
    $query  .= "left join ids on ids.sensor_id = argus.sensor_id and ids.argus_id = argus.argus_id ";
    $query  .= "where argus.sensor_id in $hp and local = ? ";
    #$query  .= "and src_bytes > 0 and dst_bytes > 0 ";
    $query  .= "and end_sec > UNIX_TIMESTAMP(DATE_SUB(now(), INTERVAL ? HOUR) ) ";
    $query  .= " group by sensor_id";

    my $sql2  = $Walleye::Util::dbh->prepare($query);


    #------ get number of flows / events in last 24 hours
    $sql->execute(1,24);
    $ref = $sql->fetchall_arrayref();
    foreach $foo(@$ref){
	$lut{$$foo[0]}{"24 Hour"}{"out"}{"con"} = $$foo[1];
        $lut{$$foo[0]}{"24 Hour"}{"out"}{"ids"} = $$foo[2];
    }
   
    #----- get number of flows / events in last 1 hours
    $sql->execute(1,1);
    $ref = $sql->fetchall_arrayref();
    foreach $foo(@$ref){
	$lut{$$foo[0]}{"1 Hour"}{"out"}{"con"} = $$foo[1];
        $lut{$$foo[0]}{"1 Hour"}{"out"}{"ids"} = $$foo[2];
    }

   
    #------ get number of flows / events in last 24 hours
    $sql->execute(0,24);
    $ref = $sql->fetchall_arrayref();
    foreach $foo(@$ref){
	$lut{$$foo[0]}{"24 Hour"}{"in"}{"con"} = $$foo[1];
        $lut{$$foo[0]}{"24 Hour"}{"in"}{"ids"} = $$foo[2];
    }
   
    #----- get number of flows / events in last 1 hours
    $sql->execute(0,1);
    $ref = $sql->fetchall_arrayref();
    foreach $foo(@$ref){
	$lut{$$foo[0]}{"1 Hour"}{"in"}{"con"} = $$foo[1];
        $lut{$$foo[0]}{"1 Hour"}{"in"}{"ids"} = $$foo[2];
    }

####################


    #------ get number of flows / events in last 24 hours
    $sql2->execute(1,24);
    $ref = $sql2->fetchall_arrayref();
    foreach $foo(@$ref){
	$lut{$$foo[0]}{"24 Hour"}{"out_t"}{"con"} = $$foo[1];
        $lut{$$foo[0]}{"24 Hour"}{"out_t"}{"ids"} = $$foo[2];
    }
   
    #----- get number of flows / events in last 1 hours
    $sql2->execute(1,1);
    $ref = $sql2->fetchall_arrayref();
    foreach $foo(@$ref){
	$lut{$$foo[0]}{"1 Hour"}{"out_t"}{"con"} = $$foo[1];
        $lut{$$foo[0]}{"1 Hour"}{"out_t"}{"ids"} = $$foo[2];
    }

   
    #------ get number of flows / events in last 24 hours
    $sql2->execute(0,24);
    $ref = $sql2->fetchall_arrayref();
    foreach $foo(@$ref){
	$lut{$$foo[0]}{"24 Hour"}{"in_t"}{"con"} = $$foo[1];
        $lut{$$foo[0]}{"24 Hour"}{"in_t"}{"ids"} = $$foo[2];
    }
   
    #----- get number of flows / events in last 1 hours
    $sql2->execute(0,1);
    $ref = $sql2->fetchall_arrayref();
    foreach $foo(@$ref){
	$lut{$$foo[0]}{"1 Hour"}{"in_t"}{"con"} = $$foo[1];
        $lut{$$foo[0]}{"1 Hour"}{"in_t"}{"ids"} = $$foo[2];
    }


   
    my $id;
    my $ip;
    my $hp_t;

    my $table = new HTML::Table(
				-padding=>3,
				-border=>0,
				);

    my $right_table = new HTML::Table(
				      -class=>'summary'
				      );

    my $htable;
    
 
    $right_table->addRow("Online Honeywalls");
    $right_table->setCellClass(1,1,"sum_h");

    
    my $url;
    my $st;
    
    foreach $id (sort keys %lut){

	$htable = new HTML::Table(
				-border=>0,
				);
	$htable->addRow(
			"<a href=\"?act=overview&sensor=$id\">".$lut{$id}{"sensor"}."</a>",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"Created: ".gmtime($lut{$id}{"created"}) . "   Last Update:  ".gmtime($lut{$id}{"last_update"}),
			""
			);

	$htable->setCellColSpan(1,1,8);
	$htable->setCellColSpan(1,9,2);
	

	

	$htable->addRow(
			"",
			"Bidirectional Flows",
			"",
			"",
			"",
			"Total Flows",
			"",
			"",
			"",
			"<img src=\"sum_graph.pl?sensor=$id;daysback=1\"/>"
			);

	$htable->setCellColSpan(2,2,4);
	$htable->setCellColSpan(2,6,4);
	$htable->setCellWidth(2,2,120);
	$htable->setCellWidth(2,6,120);

	$htable->addRow(
			"",
			"In",
			"",
			"Out",
			"",
			"In",
			"",
			"Out",
			""
			);


	$htable->setCellColSpan(3,2,2);
	$htable->setCellColSpan(3,4,2);
	$htable->setCellColSpan(3,6,2);
	$htable->setCellColSpan(3,8,2);

	$htable->setCellWidth(3,2,60);
	$htable->setCellWidth(3,4,60);
	$htable->setCellWidth(3,6,60);
	$htable->setCellWidth(3,8,60);


	$htable->addRow(
			"",
			"con",
			"ids",
			"con",
			"ids",
			"con",
			"ids",
			"con",
			"ids"
			);

	
	$htable->setCellWidth(4,2,30);
	$htable->setCellWidth(4,3,30);
	$htable->setCellWidth(4,4,30);
	$htable->setCellWidth(4,5,30);
	$htable->setCellWidth(4,6,30);
	$htable->setCellWidth(4,7,30);
	$htable->setCellWidth(4,8,30);
	$htable->setCellWidth(4,9,30);


	my $st = "st=".(time()-3600).";et=".time();
	
	$url = 	"?act=aggt&".$st."\&sensor=".$id;
	$htable->addRow(
			"<a href=\"".$url."\">1 Hour</a>",
			"<a href=\""."?act=ct&".$st."\&sensor=".$id."&src_local=0&bidi=1\">".(defined $lut{$id}{"1 Hour"}{"in"}{"con"}  ? $lut{$id}{"1 Hour"}{"in"}{"con"}  : 0)."</a>",
			(defined $lut{$id}{"1 Hour"}{"in"}{"ids"}  ? $lut{$id}{"1 Hour"}{"in"}{"ids"}  : 0),
			"<a href=\""."?act=ct&".$st."\&sensor=".$id."&src_local=1&bidi=1\">".(defined $lut{$id}{"1 Hour"}{"out"}{"con"}  ? $lut{$id}{"1 Hour"}{"out"}{"con"}  : 0)."</a>",
			(defined $lut{$id}{"1 Hour"}{"out"}{"ids"}  ? $lut{$id}{"1 Hour"}{"out"}{"ids"}  : 0),

			"<a href=\""."?act=ct&".$st."\&sensor=".$id."&src_local=0\">".(defined $lut{$id}{"1 Hour"}{"in_t"}{"con"}  ? $lut{$id}{"1 Hour"}{"in_t"}{"con"}  : 0)."</a>",
			(defined $lut{$id}{"1 Hour"}{"in_t"}{"ids"}  ? $lut{$id}{"1 Hour"}{"in_t"}{"ids"}  : 0),
			"<a href=\""."?act=ct&".$st."\&sensor=".$id."&src_local=1\">".(defined $lut{$id}{"1 Hour"}{"out_t"}{"con"}  ? $lut{$id}{"1 Hour"}{"out_t"}{"con"}  : 0)."</a>",
			(defined $lut{$id}{"1 Hour"}{"out_t"}{"ids"}  ? $lut{$id}{"1 Hour"}{"out_t"}{"ids"}  : 0),
			"",
			);



	$st = "st=".(time()-86400).";et=".time();
	
	$url = "?act=aggt&".$st."\&sensor=".$id;
	$htable->addRow(
			"<a href=\"".$url."\">24 Hour</a>",
			"<a href=\""."?act=ct&".$st."\&sensor=".$id."&src_local=0&bidi=1\">".(defined $lut{$id}{"24 Hour"}{"in"}{"con"}  ? $lut{$id}{"24 Hour"}{"in"}{"con"}  : 0)."</a>",
			(defined $lut{$id}{"24 Hour"}{"in"}{"ids"}  ? $lut{$id}{"24 Hour"}{"in"}{"ids"}  : 0),
			"<a href=\""."?act=ct&".$st."\&sensor=".$id."&src_local=1&bidi=1\">".(defined $lut{$id}{"24 Hour"}{"out"}{"con"}  ? $lut{$id}{"24 Hour"}{"out"}{"con"}  : 0)."</a>",
			(defined $lut{$id}{"24 Hour"}{"out"}{"ids"}  ? $lut{$id}{"24 Hour"}{"out"}{"ids"}  : 0),

			"<a href=\""."?act=ct&".$st."\&sensor=".$id."&src_local=0\">".(defined $lut{$id}{"24 Hour"}{"in_t"}{"con"}  ? $lut{$id}{"24 Hour"}{"in_t"}{"con"}  : 0)."</a>",
			(defined $lut{$id}{"24 Hour"}{"in_t"}{"ids"}  ? $lut{$id}{"24 Hour"}{"in_t"}{"ids"}  : 0),
			"<a href=\""."?act=ct&".$st."\&sensor=".$id."&src_local=1\">".(defined $lut{$id}{"24 Hour"}{"out_t"}{"con"}  ? $lut{$id}{"24 Hour"}{"out_t"}{"con"}  : 0)."</a>",
			(defined $lut{$id}{"24 Hour"}{"out_t"}{"ids"}  ? $lut{$id}{"24 Hour"}{"out_t"}{"ids"}  : 0),
			"",
			);


	
	$htable->setClass("summary");

	$htable->setColClass(1,"sum_body");
	$htable->setColClass(2,"sum_body");
	$htable->setColClass(3,"sum_body");
	$htable->setColClass(4,"sum_body");
	$htable->setColClass(5,"sum_body");
	$htable->setColClass(6,"sum_body");
	$htable->setColClass(7,"sum_body");
	$htable->setColClass(8,"sum_body");
	$htable->setColClass(9,"sum_body");

	$htable->setCellClass(1,1,"sum_title");
	$htable->setCellClass(1,9,"sum_tiny");

	$htable->setCellClass(2,1,"sum_body");
	$htable->setCellClass(2,2,"sum_head_t");
	$htable->setCellClass(2,6,"sum_head_t");

	$htable->setCellClass(3,2,"sum_head_t");
	$htable->setCellClass(3,4,"sum_head_t");
	$htable->setCellClass(3,6,"sum_head_t");
	$htable->setCellClass(3,8,"sum_head_t");
	
	$htable->setCellClass(4,2,"sum_head_t");
	$htable->setCellClass(4,3,"sum_head_t");
	$htable->setCellClass(4,4,"sum_head_t");
	$htable->setCellClass(4,5,"sum_head_t");
	$htable->setCellClass(4,6,"sum_head_t");
	$htable->setCellClass(4,7,"sum_head_t");
	$htable->setCellClass(4,8,"sum_head_t");
	$htable->setCellClass(4,9,"sum_head_t");
       

	$htable->setCellClass(5,1,"sum_head_l");
	$htable->setCellClass(6,1,"sum_head_l");
	$htable->setCellClass(7,1,"sum_head_l");


	$htable->setCellRowSpan(2, 10, 6);
	$htable->setCellClass(2,10,"sum_graph");

	$right_table->addRow($htable->getTable);

	
    } 
    
    if(defined $sensor_detail){
	$table->addRow($right_table->getTable);
	$table->addRow(gen_sensor_detail($sensor_detail));
    }else{
	$table->addRow($right_table->getTable);
    }
    
    $table->addRow(gen_search());
   

    #$table->setCellRowSpan(1,2,2);


    return $table->getTable;

   

    

}

sub search{
    my $q = new CGI;

    my $start     = UnixDate(ParseDate($q->param('stime')),"%s");
    my $end       = UnixDate(ParseDate($q->param('etime')),"%s");
    
    my $ip_proto  = $q->param('ip_proto');
    my $net       = $q->param('ip');
    my $snet      = $q->param('src_ip');
    my $dnet      = $q->param('dst_ip');

    my $port     = $q->param('port');
    my $sport     = $q->param('src_port');
    my $dport     = $q->param('dst_port');

    my $txbytes   = $q->param('transfered_bytes');
    my $bidi      = $q->param('bidi');
    my $format    = $q->param('result_format');

    if($format eq "Pcap File"){
	#--- reformat and send query to pcap_api
	my $query = new CGI("");
	if($start){
	    $query->param('st',$start);
	}
	if($end){
	    $query->param('et',$end);
	}

	if($net){
	    $query->param('net',$net);
	}

	if($snet){
	    $query->param('snet',$snet);
	}

	if($dnet){
	    $query->param('dnet',$dnet);
	}

	if($port){
	    $query->param('port',$port);
	}

	if($sport){
	    $query->param('sport',$sport);
	}

	if($dport){
	    $query->param('dport',$dport);
	}


	if($ip_proto){
	    $query->param('ip_proto',$ip_proto);
	}

	my $url = "pcap_api.pl?".$query->query_string();
	#print $url;
	#---- redirect to pcap api
	print $query->redirect(-uri=>$url);
	return;	

    }

    if($format eq "Walleye Flow View"){
	#--- reformat and send query to connection table
	my $query = new CGI("");

	#--- we dont have the ability to do prefixes yet in here.

	$query->param('act',"aggt");

	if($start){
	    $query->param('st',$start);
	}
	if($end){
	    $query->param('et',$end);
	}
	

	if($net){
	    my $ip;
	    my $mask;
	    ($ip,$mask) = split('/',$net);
	    
	    $query->param('ip',unpack('N',inet_aton($ip)));
	    $query->param('mask',$mask);
	}
	

	if($snet){
	    my $ip;
	    my $mask;
	    ($ip,$mask) = split('/',$snet);
	    
	    $query->param('src_ip',unpack('N',inet_aton($ip)));
	    $query->param('src_mask',$mask);
	}

	if($dnet){
	    my $ip;
	    my $mask;
	    ($ip,$mask) = split('/',$dnet);
	    
	    $query->param('dst_ip',unpack('N',inet_aton($ip)));
	    $query->param('dst_mask',$mask);
	}

	if($port){
	    $query->param('port',$port);
	}

	if($sport){
	    $query->param('src_port',$sport);
	}

	if($dport){
	    $query->param('dst_port',$dport);
	}


	if($ip_proto){
	    $query->param('ip_proto',$ip_proto);
	}

	if($bidi){
	    $query->param('bidi',$bidi);
	}

	if($txbytes){
	    $query->param('transfered_bytes',$txbytes);
	}
	
	my $url = $query->url(-path_info=>1,-query=>1);

	#---- redirect to pcap api
	print $query->redirect(-uri=>$url);
	return;	


    }

   
}


sub gen_search{

    my $q= new CGI;

  
    my $walleye_table = new HTML::Table;

    $walleye_table->addRow("Per Flow Attributes");
    $walleye_table->setCellClass(1,1,"sum_head_t");

    $walleye_table->addRow("Bytes Transfered greater than  " .$q->textfield('transfered_bytes','',8,8));

    $walleye_table->addRow(
			   $q->checkbox(-name=>'bidi',
					-checked=>0,
					-value=>'1',
					-label=>'Bidirectional Traffic ')
			   );

    $walleye_table->addRow(
			   $q->checkbox(-name=>'unicast',
					-checked=>0,
					-value=>'1',
					-disabled=>'1',
					-label=>'Unicast Endpoints ')
			   );
    
    
    $walleye_table->addRow(
			   $q->checkbox(-name=>'src_local',
					-checked=>0,
					-value=>'1',
					-label=>'Connections From Honeynet ')  
			   );
		   
    my $table = new HTML::Table(
				-class=>'summary'
				);

    $table->addRow("Search (short term soln)");
   
    

    $table->addRow("Time",
		   "Start",
		   $q->textfield('stime',POSIX::strftime("%b %e %Y %H:%M:%S",gmtime(time()-86400)),20,20),
		   "End",
		   $q->textfield('etime',POSIX::strftime("%b %e %Y %H:%M:%S",gmtime(time())),20,20),
		  
		   );


    
    $Walleye::Util::proto_lut{"0"} = 'ANY';
    $table->addRow(
		   "IP Proto",
		   "",
		   $q->popup_menu(-name=>'ip_proto',
				  -values=>[sort {$a<=>$b} keys %Walleye::Util::proto_lut],
				  -labels=>\%Walleye::Util::proto_lut ),
		   "",
		   "",
		   
		   );
 
    $table->addRow("Either",
		   "Prefix",
		   $q->textfield('ip','',18,18),
		   "Port",
		   $q->textfield('port','0',7,7)
		   );
    

    $table->addRow("Source",
		   "Prefix",
		   $q->textfield('src_ip','',18,18),
		   "Port",
		   $q->textfield('src_port','0',7,7)
		   );

    $table->addRow("Destination",
		   "Prefix",
		   $q->textfield('dst_ip','',18,18),
		   "Port",
		   $q->textfield('dst_port','0',7,7)
		   );


   

    $table->addRow(
		   "Result Format",
		   "",
		   $q->popup_menu(-name=>'result_format',
				  -values=>["Pcap File", "Walleye Flow View"],
				  -onChange=>"if(search.result_format.value == \"Walleye Flow View\"){document.getElementById('walleye_opts').style.visibility='visible';}else{ document.getElementById('walleye_opts').style.visibility='hidden';}"
				  ),
		   "",
		   ""
		   );

    $table->addRow(
		   "",
		   "<DIV ID=\"walleye_opts\" style=\"visibility:hidden\">".$walleye_table->getTable."</DIV>"
		   );

    $table->addRow(
		   "","","",$q->submit
		   );

    $table->setColClass(1,"sum_head_l");
    $table->setColClass(2,"sum_head_t");
    $table->setColClass(3,"sum_head_t");
    $table->setColClass(4,"sum_head_t");
    $table->setColClass(5,"sum_head_t");
    $table->setCellColSpan(1,1,5);
    $table->setCellColSpan(7,3,3);
    $table->setCellColSpan(8,2,4);
   
    $table->setCellClass(1,1,"sum_h");

    $q->param('act','search');
    return $q->start_form(-method=>'get',-name=>'search',-action=>$q->url()). $q->hidden("act").$table->getTable .$q->end_form ;
    
}



sub main{

    my $act = "overview";
    

    my $page;
    my $body;
    

    #----- check the user 
    my $session = Walleye::Login::validate_user();
    my $role    = $session->param("role");
    my $sess_cookie = cookie(CGISESSID => $session->id);


    #----- get input and setup -------------
    $act = param('act');
    Walleye::Util::setup(1,1,1);


    #--- search is different, and should probably go in its own file.
    if($act && $act eq "search"){
	search();
	return;
    }

   if($act && $act eq "snortdecode"){
	Walleye::Flow::snort_decode();
	return;
    }


    #----- generate HTML ---------
   

    print header( -TYPE    => 'text/html',
		  -EXPIRES => 'now',
		  -cookie  => $sess_cookie,
		  -meta=>{'refresh'=>60}	
		  );

    $page = new HTML::Table(
			    -padding=>0,
			    -border=>0,

			    );

    if($act && $act eq "ctf"){
	print "<html class=\"et\"><head>\n";
    }else{
	print "<html><head>\n";
    }

    print "<meta http-equiv=\"refresh\" content=\"60\">"; 
 
    print "<link rel=\"stylesheet\" href=\"walleye.css\" type=\"text/css\">\n";
    print "</head>\n";
 

    $body = new HTML::Table(
			      -spacing=>0,
			      -padding=>15,
			      );

    
    #----- generate correct page based on input
    if(!$act){
	 print "<body>";
        $page->addRow(gen_nav_bar(1,$role));
        $body->addRow(gen_overview());   
    }elsif($act eq "ct"){
	print "<body>";
	#----- connection table request
	print "<a name=\"ct\"></a>\n";
	$page->addRow(gen_nav_bar(1,$role));    
	$body->addRow(Walleye::Connection_table::get_table());

    }elsif($act eq "aggf"){ 
	print "<body class=\"et\">";
	print Walleye::Aggregate_flow::get_frame();
	print "</body></html>\n";
	return;
     }elsif($act eq "aggt"){
	print "<body>";
	#----- connection table request
	print "<a name=\"ct\"></a>\n";
	$page->addRow(gen_nav_bar(1,$role));    
	$body->addRow(Walleye::Aggregate_flow::get_table());
    }elsif($act eq "admin"){
	print "<body>";
	#----- connection table request
	print "<a name=\"admin\"></a>\n";
	$page->addRow(gen_nav_bar(2,$role));    
	$body->addRow(Walleye::Admin::get_table());
    }elsif($act eq "ctf"){ 
	print "<body class=\"et\">";
	print Walleye::Connection_table::get_frame();
	print "</body></html>\n";
	return;
    }elsif($act eq "flowdf"){
	print "<body class=\"et\">";
        print Walleye::Flow::get_frame();
        print "</body></html>\n";
        return;
    }elsif($act eq "off"){ 
	print "<body class=\"et\">";
	print Walleye::Process::get_opened_files();
	print "</body></html>\n";
	return;
    }elsif($act eq "fdf"){ 
	print "<body class=\"et\">";
	print Walleye::Process::get_fd_sum();
	print "</body></html>\n";
	return;
     }elsif($act eq "fdd"){ 
	print "<body class=\"et\">";
	print Walleye::Process::get_fd_details();
	print "</body></html>\n";
	return;
    }elsif($act eq "hd"){
	print "<body>";
	#----- host details request
	$page->addRow(gen_title_bar());   
	$body->addRow(Walleye::Host::get_hd());
    
    }elsif($act eq "tree"){
	print "<body>";
        $page->addRow(gen_nav_bar(1,$role));
	$body->addRow(Walleye::Process_tree::get_table());
	
    }elsif($act eq "treef"){
	print "<body>";
	print Walleye::Process_tree::get_frame();
	print "</body></html>\n";
	return;
        
    }elsif($act eq "pd"){
	print "<body>";
	#---- process detail
	$page->addRow(gen_nav_bar(1,$role));
	$body->addRow(Walleye::Process::get_frame());

    }else{
	print "<body>";
	$page->addRow(gen_nav_bar(1,$role));    
	$body->addRow(gen_overview());
    } 


    $page->addRow($body->getTable);

    $page->print;
    print "</body></html>\n";
    
}


main();
