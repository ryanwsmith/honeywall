# (C) 2005 The Trustees of Indiana University.  All rights reserved.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
# 
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

#
#----- Walleye:  Honeywall Data Analysis Interface
#-----
#----- Agregate Flow View
#-----
#----- Version:  $Id: Aggregate_flow.pm 2080 2005-08-24 17:31:31Z cvs $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  


package Walleye::Aggregate_flow;
use strict;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;
use Date::Calc qw(:all);
use Date::Manip;
use HTML::Table;
use HTML::Entities;
use HTML::CalendarMonthSimple;
use CGI qw/:standard/;
use Socket;

use Walleye::Util;
use Walleye::Connection_table;



#----- Module stuff

require Exporter;
our @ISA=("Exporter");
#our @EXPORT = qw (get_table get_frame);

my $limit = 30;
	    



#----- generate the internal connection table frame
sub get_table{

    my $start_time = param('st');
    my $end_time   = param('et');
    #if(!$start_time){$start_time = time();}
    #if(!$end_time){$end_time = time() - 360;}

    

    my $table  = new HTML::Table(#-class=>'et',
				 -spacing=>0,
				 -padding=>0,
				 -border=>0);

    my $title;
    $title = "Aggregated Flows:  ";


    if(!param('aggby')){
	param('aggby','dst_ip');
    }

    if(param('aggby')){
	$title .= " Aggregated by ".param('aggby');
    }

    if(param('ids')){
	$title .= " triggering IDS events ";
    }

    if(param('ip')){
	$title .= " related to ".inet_ntoa(pack('N',param('ip')));
    }
    if(param('dip')){
	$title .= " Going to ".inet_ntoa(pack('N',param('dip')));	
    }

     if(param('sip')){
	$title .= " Coming from ".inet_ntoa(pack('N',param('sip')));	
    }
    

    if(param("process_id")){
	$title .= "related to Process_ID:  ".param("process_id");
    }

    if(param("sensor")){
	$title .= " Observed from Sensor ".param("sensor")." ";
    }

    if(param("ip_proto")){
	my $proto_txt = ($Walleye::Util::proto_lut{param('ip_proto')}) ?  ($Walleye::Util::proto_lut{param('ip_proto')}) : param('ip_proto');
	$title .= " With IP Protocol $proto_txt ";
    }
   
    if(param('all_times')){
	$title .=  " For all time periods ";
    }else{
	$title .= " Between ".gmtime($start_time)." and ".gmtime($end_time)." ";
    }

    if(param("process_tree_con")){
	$title .= "<br>Which are related to Connection ID ".param("process_tree_con").", through a shared process tree";
    }
 
   
   
    my $rtable  = new HTML::Table(
                         -spacing=>0,
                         -padding=>0,
                         -border=>0);
   
 
    param("act","aggf");


    if(!param('page')){
      param('page',1);
    }

    $rtable->addRow($title);
    $rtable->setCellClass(1,1,'et_title');
    $rtable->addRow(get_frame());

    $table->addRow(Walleye::Connection_table::get_navbar("aggt"),$rtable->getTable);
    
    $table->setCellClass(1,1,"et_cal");
    $table->setCellClass(1,2,'et');

    return $table->getTable;
}



sub get_frame{
    my $query;
    my $sql;
    my $ref;
    my $line;
    my $foo;
 
    my $sensor     = param('sensor');
    my $src_local  = param('src_local');
   
    my $process_id = param('process_id');
    my $process_tree=param('process_tree');
    my $process_tree_con = param('process_tree_con');   #--- I should be sued for crapy parameter names like this


    my @time = gmtime(time());

  

    my $q = new CGI;
    Walleye::Util::scrub_cgi(\$q);
   

    my $start_time = param('st');
    my $end_time   = param('et');
    #if(!$start_time){$start_time = time();}
    #if(!$end_time){$end_time = time() - 360;}

 
    my @bindings;
    my @bindings2;

    my %lut;
    my $and;
    my $and2;


    
    my $target = 'dst_ip'; 
   
    if(param('aggby')){ 
      if(param('aggby') eq "src_ip"){
	$target = "src_ip";
      }elsif(param('aggby') eq "src_port"){
	$target = "src_port";
      }elsif(param('aggby') eq "dst_port"){
	$target = "dst_port";
      }
    }

    param('aggby',$target);

    my $aggby  = Walleye::Util::aggregate_by($target); 

     
    #--- saddly we can not format inside of mysql because it will
    #--- order the results alphabetically.
    $query  = "select $target ,  ";
    $query .= " FORMAT(COUNT(DISTINCT(argus.argus_id)),0) , ";
    $query .= " FORMAT(COUNT(DISTINCT(ids.ids_id)),0) , ";
    $query .= " FORMAT(COUNT(DISTINCT(src_port)),0) , ";
    $query .= " FORMAT(COUNT(DISTINCT(dst_port)),0) , ";
    $query .= " FORMAT(SUM(src_pkts),0) , ";
    $query .= " FORMAT(SUM(src_bytes),0) , ";
    $query .= " FORMAT(SUM(dst_pkts),0) , ";
    $query .= " FORMAT(SUM(dst_bytes),0) , ";
    $query .= " FORMAT(MAX(src_pkts),0) , ";
    $query .= " FORMAT(MAX(src_bytes),0) , ";
    $query .= " FORMAT(MAX(dst_pkts),0) , ";
    $query .= " FORMAT(MAX(dst_bytes),0),  ";
    #--- so as an ugly hack duplicate the results wo formatting
    $query .= " $target ,  ";
    $query .= " COUNT(DISTINCT(argus.argus_id)) , ";
    $query .= " COUNT(DISTINCT(ids.ids_id)) , ";
    $query .= " COUNT(DISTINCT(src_port)) , ";
    $query .= " COUNT(DISTINCT(dst_port)) , ";
    $query .= " SUM(src_pkts) , ";
    $query .= " SUM(src_bytes) , ";
    $query .= " SUM(dst_pkts) , ";
    $query .= " SUM(dst_bytes) , ";
    $query .= " MAX(src_pkts) , ";
    $query .= " MAX(src_bytes) , ";
    $query .= " MAX(dst_pkts) , ";
    $query .= " MAX(dst_bytes)  ";

    $query .= " from argus ";
    $query .= " left join ids on ids.sensor_id = argus.sensor_id and ids.argus_id = argus.argus_id ";

    $query .= " where ";

    $query  .= Walleye::Util::gen_flow_query_filter($q,\@bindings,\$and,  param('all_times'));


    $query  .= " group by  $target ";
    

    if(param('order') && param('order') >= 0 && param('order') < 13){
	my $order = int(param('order')) + 13;
	$query .= "order by $order desc, 1 desc ";
    }else{
	$query .= "order by 1 desc ";
    }
   
  
    


    #--- used to get total count
    my $query2 = "select FORMAT(COUNT(DISTINCT($target)),0) from argus left join ids on ids.sensor_id = argus.sensor_id and ids.argus_id = argus.argus_id where ";

  
    $query2 .= Walleye::Util::gen_flow_query_filter($q,\@bindings2,\$and2, param('all_times'));
    
   
  


    my $page;
    my $start;
    if(param('page') && param('page') > 0 && param('page') < 1000000){
	$page = param('page');
	$start = ($page -1 ) * $limit;
    }else{
	$page = 1;
	$start = 0;

    }

    $query .= " limit $start,$limit  ";

    
    #---- get total number
    $sql = $Walleye::Util::dbh->prepare($query2);

    
    $sql->execute(@bindings2);
    $ref = $sql->fetchall_arrayref();
    
    my $total_rows  = $$ref[0][0];
    my $total_pages = int($total_rows / $limit)+1;

   
    
    #--- get the page of data specified
    $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute(@bindings);
    $ref = $sql->fetchall_arrayref();
    
  
    
    #----- put flow data into hash
    my $aggtable = new HTML::Table(-border=>0,-spacing=>0,-padding=>0);
  

    my $x;
    my $index;

    
    $aggtable->addRow(Walleye::Util::result_pager($page,$total_pages));
    $aggtable->setCellColSpan(1,1,13);
    $aggtable->addRow("Aggregate By","Aggregate Totals","","","","","","","", "Individual Flow Maximums","","","");
    $aggtable->setCellColSpan(2,2,8);
    $aggtable->setCellColSpan(2,10,4);
	
    $q->delete('order');
    $aggtable->addRow($aggby,
		      "<a href=\"".$q->url(-query=>1)."&order=2\">Flows</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=3\">Alerts</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=4\">SRC Ports</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=5\">DST Ports</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=6\">SRC pkts</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=7\">SRC bytes</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=8\">DST pkts</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=9\">DST bytes</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=10\">SRC pkts</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=11\">SRC bytes</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=12\">DST pkts</a>",
		      "<a href=\"".$q->url(-query=>1)."&order=13\">DST bytes</a>");


    $q->param('act','ct');

    $q->delete('page');

    my $orig_target = $target;
    foreach $line(@$ref){
	$target = $orig_target;
	undef $index;
	if($target eq "src_ip" || $target eq "dst_ip"){
	     #--- loosen up the specificity
	    $q->delete($target);
	    $target = "ip";

	    $index = inet_ntoa(pack('N',$$line[0]));
	   
	    
	}elsif($target eq "dst_port" || $target eq "src_port"){
	    #--- loosen up the specificty
	    $q->delete($target);
	    $target = "port";

	    $index = $Walleye::Util::port_lut{$Walleye::Util::proto_lut{"6"}}{$$line[0]};
	    if(!$index){
		$index = $Walleye::Util::port_lut{$Walleye::Util::proto_lut{"17"}}{$$line[0]};
	    }
	    if(!$index){
		$index = $$line[0];
	    }
	    $index = "<font color=006600><b>".$index."<b></font>";
	}else{
	    $index = $$line[0];
	}

	$q->param($target,$$line[0]);
	
	$index = "<a target=\"_top\" href=\"".$q->url(-query=>1)."\">". $index."</a>";


	$$line[0] = $index;

	$aggtable->addRow(@$line[0..12]);



	if($x++ %2){
	    $aggtable->setLastRowClass('et_odd');
	}else{
	    $aggtable->setLastRowClass('et_even');
	}


    }

    
    $aggtable->setColClass(1,'aggregate_flow_rt');	
    $aggtable->setColClass(2,'aggregate_flow');
    $aggtable->setColClass(3,'aggregate_flow');
    $aggtable->setColClass(4,'aggregate_flow');
    
    $aggtable->setColClass(5,'aggregate_flow_rt');
    $aggtable->setColClass(6,'aggregate_flow');
    $aggtable->setColClass(7,'aggregate_flow');
    $aggtable->setColClass(8,'aggregate_flow');
    $aggtable->setColClass(9,'aggregate_flow_rt');
    $aggtable->setColClass(10,'aggregate_flow');
    $aggtable->setColClass(11,'aggregate_flow');
    $aggtable->setColClass(12,'aggregate_flow');
    $aggtable->setColClass(13,'aggregate_flow');
    $aggtable->setColClass(14,'aggregate_flow');
    
    $aggtable->setCellClass(1,1,'aggregate_flow_index');
    $aggtable->setCellClass(2,1,'aggregate_flow_index');
    $aggtable->setCellClass(2,2,'aggregate_flow_index');
    $aggtable->setCellClass(2,10,'aggregate_flow_index');
    
    $aggtable->setCellClass(3,1,'aggregate_flow_index');
    $aggtable->setCellClass(3,2,'aggregate_flow_index');
    $aggtable->setCellClass(3,3,'aggregate_flow_index');
    $aggtable->setCellClass(3,4,'aggregate_flow_index');
    $aggtable->setCellClass(3,5,'aggregate_flow_index');
    $aggtable->setCellClass(3,6,'aggregate_flow_index');
    $aggtable->setCellClass(3,7,'aggregate_flow_index');
    $aggtable->setCellClass(3,8,'aggregate_flow_index');
    $aggtable->setCellClass(3,9,'aggregate_flow_index');
    $aggtable->setCellClass(3,10,'aggregate_flow_index');
    $aggtable->setCellClass(3,11,'aggregate_flow_index');
    $aggtable->setCellClass(3,12,'aggregate_flow_index');
    $aggtable->setCellClass(3,13,'aggregate_flow_index');


    return $aggtable->getTable;
}
