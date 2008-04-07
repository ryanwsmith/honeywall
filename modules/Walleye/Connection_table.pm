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


#----- Walleye:  Honeywall Data Analysis Interface
#-----
#----- Connetion Table View
#-----
#----- Version:  $Id: Connection_table.pm 2500 2005-12-12 17:01:14Z edb $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  


package Walleye::Connection_table;
use strict;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;
use Date::Calc qw(:all);
use Time::Local;
use HTML::Table;
use HTML::Entities;
use HTML::CalendarMonthSimple;
use CGI qw/:standard/;
use Socket;

use Walleye::Util;

my $limit = 25;

#----- Module stuff

require Exporter;
our @ISA=("Exporter");
#our @EXPORT = qw (get_table get_frame get_navbar);

#-----
#--- this sick fctn needs to be reworked it has more holes than swiss cheeze.
sub get_navbar{
#---- this is all kinds of broken due to stupid design.
    my $act        = shift;
    my $cgi_copy  = new CGI;
    
    my $start_time = $cgi_copy->param('st');
    my $end_time   = $cgi_copy->param('et');


    #--- doesnt make sense to have all_times or page set
    $cgi_copy->delete('all_times');
    $cgi_copy->delete('page');
    
    Walleye::Util::scrub_cgi(\$cgi_copy);
    
    my @bindings;
    
    my $process_id = param('process_id');
    
    my @time;
    my $cal;
    
    if($start_time > 0){  
	@time = gmtime($start_time);
	my $year   = 1900 + $time[5];
	my $month  = 1 + $time[4];
	my $day    = $time[3];
	$cal = new HTML::CalendarMonthSimple ('today_year'=>$year,'today_month'=>$month,'today_date'=>$day);
    }else{
	$cal =  new HTML::CalendarMonthSimple();
    }
    
    $cal->border(0);
    $cal->weekdayheadersbig(0);
    
    $cal->sunday('sun');
    $cal->saturday('sat');
    $cal->weekdays('mon','tue','wed','thu','fri');
    $cal->weekendcolor("cyan");
    $cal->todaycolor('yellow');
    
    $cal->tableclass('cal');
    $cal->headerclass('cal_dayhead');
    $cal->cellclass('cal_cell');
    $cal->weekdaycellclass('cal_weekday');
    $cal->weekendcellclass('cal_weekend');
    $cal->sharpborders(1);

    my $query;
    
    my $and = 0; 
    
    if(!defined param('process_id') && !defined param('process_tree') && !defined param('process_tree_con')){ 
	$query  = "select  FORMAT(count(distinct argus.argus_id ),0), FORMAT(count(distinct ids.ids_id),0) from argus  ";
	$query .= "left join ids on ids.sensor_id = argus.sensor_id and ids.argus_id = argus.argus_id ";
	$query .= "  where    ";
	
	
	$query .= Walleye::Util::gen_flow_query_filter($cgi_copy,\@bindings,\$and,1);
	
	if($and){
	    $query .=" and  end_sec >= ? and start_sec <= ?  ";
	}else{ 
	    $query .= "  end_sec >= ? and start_sec <= ?  ";
	}
    }

    if(defined param('process_id')){
	$query  = "select  FORMAT(count(distinct argus.argus_id),0), FORMAT(count(distinct ids.ids_id),0) from argus, process, sys_socket ";
	$query .= "left join ids on ids.sensor_id = argus.sensor_id and ids.argus_id = argus.argus_id ";
	$query .= " where argus.argus_id = sys_socket.argus_id and argus.sensor_id = sys_socket.sensor_id and sys_socket.process_id = process.process_id and  ";
	$query .= " process.sensor_id = argus.sensor_id  ";
	
	if(param('process_id') ne "any"){
	    $query .= " and process.process_id = $process_id ";
	}
	
	if(defined param('sensor')){
	    $query .= " and argus.sensor_id = ".param('sensor')."   ";
	}
	if(defined param('ip_proto')){
	    $query .= " and argus.ip_proto = ".param('ip_proto')." ";
	}
	
	$query .= " and  end_sec >= ? and start_sec <= ?   ";
#push(@bindings,$start_time);
#push(@bindings,$end_time);
    }

    if(param('process_tree') || param('process_tree_con')){
	my @processes;
	my @results;
	
#print "process tree<br>\n";
	
	if(param('process_tree_con')){
	    Walleye::Util::get_processes_by_con_id(\@processes,param('process_tree_con'),param('sensor'));
	  }else{
	      $processes[0][0] = param('process_tree');
	  }
	push(@results,@processes);
	
	Walleye::Util::get_decendant_processes(\@processes,\@results,1,param('sensor'));
	
	push(@results,@processes);
	
	Walleye::Util::get_ancestor_processes(\@processes,\@results,1,param('sensor'));
	
	push(@results,@processes);
	
	my $in = Walleye::Util::array_to_in(\@results,0);
	
	$query  = "select  FORMAT(count(distinct argus.argus_id),0), FORMAT(count(distinct ids.ids_id),0) from argus, process, sys_socket ";
	$query .= "left join ids on ids.sensor_id = argus.sensor_id and ids.argus_id = argus.argus_id ";
	$query .= " where argus.argus_id = sys_socket.argus_id and argus.sensor_id = sys_socket.sensor_id and sys_socket.process_id = process.process_id and  ";
	$query .= " process.process_id in $in and process.sensor_id = argus.sensor_id and argus.sensor_id = ? ";
	
	push(@bindings,param('sensor'));
	if(defined param('ip_proto')){
	    $query .= " and argus.ip_proto = ? ";
	    push(@bindings,param('ip_proto'));
	} 
	
	
	$query .= " and  end_sec >= ? and start_sec <= ?   ";
	
    }
    
    
    my $sql = $Walleye::Util::dbh->prepare($query);
    
    my $ref;
    my $x;
    my @gmt;
    my %lut;
    my $line;
    my $tmp_hr;
    
    
    
    if($start_time > 0){ 
	@time = gmtime($start_time);
    }else{
	@time = gmtime(time());
    }
    
#--- query counts for each hour
    for($time[2]=0;$time[2]<24;$time[2]++){
	push(@bindings,timegm(0,0,$time[2],$time[3],$time[4],$time[5]));
	push(@bindings,timegm(59,59,$time[2],$time[3],$time[4],$time[5]));
	$sql->execute(@bindings);
	pop(@bindings);
	pop(@bindings);
	
	$ref = $sql->fetchall_arrayref();
	$lut{$time[2]}{"flows"} = $$ref[0][0];
	$lut{$time[2]}{"ids"}   = $$ref[0][1];
    }
    
#return;
    
    
    #--- boy this sure is redundant.
    $cgi_copy->delete('all_times');
    $cgi_copy->delete('page');
    
#--- create the calender
    if($start_time > 0){
	@time = gmtime($start_time);
    }else{
	@time = gmtime(time());
    }
    
    my $dom = Date::Calc::Days_in_Month(1900+$time[5],$time[4]+1);
    for($time[3]=1;$time[3]<=$dom;$time[3]++){
	$cgi_copy->param('st',timegm(0,0,0,$time[3],$time[4],$time[5]));
	$cgi_copy->param('et',timegm(59,59,23,$time[3],$time[4],$time[5]));
	$cal->setdatehref($time[3],$cgi_copy->url(-query=>1));	
    }
    
    
#---- reset the cgi copy !?!?!?!
    $cgi_copy = new CGI;
    $cgi_copy->delete('all_times'); 
    $cgi_copy->delete('page');

    Walleye::Util::scrub_cgi(\$cgi_copy);
    
#--- create the day table
    my $table = new HTML::Table(-border=>0,-padding=>0,-spacing=>0);    
    my $hour_table = new HTML::Table(-border=>0,-padding=>0,-spacing=>0);
    
    $hour_table->addRow("Hour","Cons","IDS");
    
    
    my $ids_str;
    my $flow_str;
    
    if($start_time > 0){ 
	@time = gmtime($start_time);
    }else{
	@time = gmtime(time());
    }
    
    for($time[2]=0;$time[2]<24;$time[2]++){
	$cgi_copy->param('st',timegm(0,0,$time[2],$time[3],$time[4],$time[5]));
	$cgi_copy->param('et',timegm(59,59,$time[2],$time[3],$time[4],$time[5]));
	$cgi_copy->delete("ids");
	$flow_str = "<a href=\"".$cgi_copy->url(-query=>1)."\">". $lut{$time[2]}{"flows"}."</a>",
	$cgi_copy->param("ids","1");
	$ids_str = "<a href=\"".$cgi_copy->url(-query=>1)."\">". $lut{$time[2]}{"ids"}."</a>",
	
	$hour_table->addRow(
			    "$time[2]".":00",
			    $flow_str,
			    $ids_str
			    );
	
	
	if(timegm(0,0,$time[2],$time[3],$time[4],$time[5]) == $start_time){
	    $hour_table->setLastRowClass('et_select');
	}else{
	    if($time[2] && $time[2] % 2){
		$hour_table->setLastRowClass('et_even');
	    }else{
		$hour_table->setLastRowClass('et_odd');
	    }
	}
    }
    
    
    $hour_table->setColClass(1,'ht');
    $hour_table->setColClass(2,'ht');
    $hour_table->setColClass(3,'ht');
    $hour_table->setCellClass(1,1,'sum_head_t');
    $hour_table->setCellClass(1,2,'sum_head_t');
    $hour_table->setCellClass(1,3,'sum_head_t');
    
    $table->addRow($cal->as_HTML);
    
#---- reset the cgi copy
    $cgi_copy = new CGI;
    $cgi_copy->delete('all_times');
    $cgi_copy->delete('page');
    
    if($start_time > 0){
	@time = gmtime($start_time);
    }else{
	@time = gmtime(time());
    }
    
    Walleye::Util::scrub_cgi(\$cgi_copy);
    
    ($time[5],$time[4],$time[3]) = Add_Delta_YM($time[5],$time[4]+1,1,0,-1);
    $time[4]--;

    $cgi_copy->param('st',timegm(@time));
    my $prior = "<a href=\"".$cgi_copy->url(-query=>1)."\">(Prior Month)</a>";
    
    ($time[5],$time[4],$time[3]) = Add_Delta_YM($time[5],$time[4]+1,1,0,2); 
    $time[4]--;

    $cgi_copy->param('st',timegm(@time));
    my $next = "<a href=\"".$cgi_copy->url(-query=>1)."\">(Next Month)</a>";
    
    
    $table->addRow("$prior $next");
    
    $table->addRow($hour_table->getTable);
    
    $table->addRow(Walleye::Util::select_flow_table());
    
    return $table->getTable;
}


#----- generate the internal connection table frame
sub get_table{
    
    my $start_time = param('st');
    my $end_time   = param('et');
#if(!$start_time){$start_time = time();}
#if(!$end_time){$end_time = time() - 360;}
    
    my @time = gmtime(time());
    
    
    my $table  = new HTML::Table(#-class=>'et',
				 -spacing=>0,
				 -padding=>0,
				 -border=>0);
    
    my $title;
    $title = "Connections ";
    
    if(param('ids')){
	$title .= "triggering IDS events ";
    }
    
    
    
    if(param('ip')){
	$title .= " related to ".inet_ntoa(pack('N',param('ip')));
    }
    if(param('mask')){
	$title .= "/ ".param('mask');	
    }
    
    if(param('dst_ip')){
	$title .= " Going to ".inet_ntoa(pack('N',param('dst_ip')));	
    }
    if(param('dst_mask')){
	$title .= "/ ".param('dst_mask');	
    }
    
    if(param('src_ip')){
	$title .= " Coming from ".inet_ntoa(pack('N',param('src_ip')));	
    }
    if(param('src_mask')){
	$title .= "/ ".param('src_mask');	
    }
    
    if(param("process_id")){
	$title .= "related to Process_ID:  ".param("process_id");
    }
    
    if(param("sensor")){
	$title .= " Observed from Sensor ".param("sensor")." ";
    }
    
    if(param("ip_proto")){
#----- load up protocol mappings
	my $proto_txt = ($Walleye::Util::proto_lut{param('ip_proto')}) ?  ($Walleye::Util::proto_lut{param('ip_proto')}) : param('ip_proto');
	$title .= " With IP Protocol $proto_txt ";
    }
    
    if(param('all_times')){
	$title .=  " For all time periods ";
    }else{
	if($start_time > 0){
	    $title .= " After ".gmtime($start_time);
	}
	if($end_time > 0){
	    $title .= " Before ".gmtime($end_time);
	    
	}
    }
    
    if(param("process_tree_con")){
	$title .= "<br>Which are related to Connection ID ".param("process_tree_con").", through a shared process tree";
    }
    
    my $q= new CGI;
    Walleye::Util::scrub_cgi(\$q);
    
    my $rtable  = new HTML::Table(
				  -spacing=>0,
				  -padding=>0,
				  -border=>0);
   

    param("act","ctf");

 
    if(!param('page')){
	param('page',1);
    }
    
    $rtable->addRow($title);
    $rtable->setCellClass(1,1,'et_title');
    $rtable->addRow(get_frame());
    
    $table->addRow(get_navbar("ct"),$rtable->getTable);
    $table->setCellClass(1,1,'et_cal');
    $table->setCellClass(1,2,'et');
    
    
    return $table->getTable;
}


sub get_frame{
    my $query;
    my $query2;
    my $sql;
    my $ref;
    my $line;
    my $foo;
    
    my $sensor     = param('sensor');
    my $src_local  = param('src_local');
    
    my $process_id = param('process_id');
    my $process_tree=param('process_tree');
    my $process_tree_con = param('process_tree_con');   #--- I should be sued for crapy parameter names like this
    

    my $start_time = param('st');
    my $end_time   = param('et');
#if(!$start_time){$start_time = time();}
#if(!$end_time){$end_time = time() - 360;}
    
    my @time = gmtime(time());
    
    my @bindings;
    my @bindings2;
    
    my %lut;
    
    
    my $total_pages = 1;
    my $start;
    my $page;
    
    
    

    if($process_id ){
	$query  = "select start_sec, end_sec - start_sec, FROM_UNIXTIME(start_sec,\"%M %D %H:%I:%S\"), ";
# 3 -> 9 
	$query .= " argus.argus_id, ip_proto, argus.src_ip, src_port, os.genre, argus.dst_ip, dst_port,  ";
# 10 -> 13
	$query .= " src_pkts, src_bytes, dst_pkts, dst_bytes, argus.sensor_id, ";
	
	$query  .= " ids.ids_id, MIN(ids.sec), ids.priority, sig_name, ids.type, count(ids.ids_id), argus.argus_dir, argus.argus_status, ";
	
	$query .= "  process.pid, process.process_id ";
	
	$query .= " from argus, sys_socket, process ";
	$query .= " left join os on argus.client_os_id = os.os_id and os.sensor_id = argus.sensor_id ";
	$query .= " left join ids on ids.argus_id = argus.argus_id and ids.sensor_id = argus.sensor_id ";
	$query .= " left join ids_sig on ids.sig_id = ids_sig.ids_sig_id and ids.sensor_id = ids_sig.sensor_id ";
	$query .= " where argus.argus_id = sys_socket.argus_id and sys_socket.process_id = process.process_id  ";
	
	if(defined param('sensor')){
	    $query .= " and  argus.sensor_id = ?  ";
	    push(@bindings,param('sensor'));
	}
	
	if($process_id eq "any"){
	    
	}else{
	    $query .= " and process.process_id = ? ";
	    push(@bindings,$process_id);
	}
	
	if(defined param('ip_proto')){
	    $query .= " and   argus.ip_proto = ? ";
	    push(@bindings,param('ip_proto'));	
	}
	
	if(!defined param('all_times') && $start_time && $end_time){
	    $query .= "   and end_sec >= ? and start_sec <= ?   ";
	    push(@bindings,$start_time);
	    push(@bindings,$end_time);
	}
	
	$query .= "  group by argus.sensor_id, argus.argus_id, ids.sig_id order by start_sec ";
	
	
	$sql = $Walleye::Util::dbh->prepare($query);
	$sql->execute(@bindings);

	$ref = $sql->fetchall_arrayref();
	
    }elsif($process_tree || $process_tree_con){
	my @processes;
	my @results;
	
#print "process tree<br>\n";
	
	if($process_tree_con){
	    Walleye::Util::get_processes_by_con_id(\@processes,$process_tree_con,param('sensor'));
	  }else{
	      $processes[0][0] = $process_tree;
	  }
	push(@results,@processes);
	
	Walleye::Util::get_decendant_processes(\@processes,\@results,1,param('sensor'));
	
	push(@results,@processes);

	Walleye::Util::get_ancestor_processes(\@processes,\@results,1,param('sensor'));
	
	push(@results,@processes);
	
	my $in = Walleye::Util::array_to_in(\@results,0);
	
	
	$query  = "select start_sec, end_sec - start_sec, FROM_UNIXTIME(start_sec,\"%M %D %H:%I:%S\"), ";
# 3 -> 9 
	$query .= " argus.argus_id, ip_proto, argus.src_ip, src_port, os.genre, argus.dst_ip, dst_port,  ";
# 10 -> 14
	$query .= " src_pkts, src_bytes, dst_pkts, dst_bytes, argus.sensor_id, ";
	
	$query  .= " ids.ids_id, MIN(ids.sec), ids.priority, sig_name, ids.type, count(ids.ids_id), argus.argus_dir, argus.argus_status, ";
	$query .= " process.pid, process.process_id ";
	
	$query .= " from argus, sys_socket, process ";
	$query .= " left join os on argus.client_os_id = os.os_id and argus.sensor_id = os.sensor_id ";
	$query .= " left join ids on ids.argus_id = argus.argus_id and ids.sensor_id = argus.sensor_id ";
	$query .= " left join ids_sig on ids.sig_id = ids_sig.ids_sig_id and ids.sensor_id = ids_sig.sensor_id ";
	$query .= " where argus.argus_id = sys_socket.argus_id and sys_socket.process_id = process.process_id and ";
	$query .= " process.process_id in $in  and argus.sensor_id = ? ";
	
	push(@bindings,$sensor);
	
	if(!defined param('all_times') && $start_time && $end_time){
	    $query .= "   and end_sec >= ? and start_sec <= ?   ";
	    push(@bindings,$start_time);
	    push(@bindings,$end_time);
	}
	
	if(defined param('ip_proto')){
	    $query .= " and   argus.ip_proto = ? ";
	    push(@bindings,param('ip_proto'));	
	}
	
	$query .= " group by argus.sensor_id, argus.argus_id, ids.sig_id  order by  start_sec ";
	$sql = $Walleye::Util::dbh->prepare($query);
	
	$sql->execute(@bindings);
	$ref = $sql->fetchall_arrayref();
	
    }else{
#print "I am here<br>\n";
	my $and = 0;
	my $and2 = 0;
#----- get connection records -----------------------------------------------------------------
# 0 - > 2
	$query  = "select start_sec, end_sec - start_sec, FROM_UNIXTIME(start_sec,\"%M %D %H:%i:%S\"), ";
# 3 -> 9 
	$query .= " argus.argus_id, ip_proto, argus.src_ip, src_port, os.genre, argus.dst_ip, dst_port,  ";
# 10 -> 14
	$query .= " src_pkts, src_bytes, dst_pkts, dst_bytes, argus.sensor_id, ";
# 15 -> 22
	$query  .= " ids.ids_id, MIN(ids.sec), ids.priority, ids_sig.sig_name, ids.type, count(ids_sig.ids_sig_id), argus.argus_dir, argus.argus_status, ";

# 23 -> 24
	$query .= " process.pid, process.process_id ";
	$query .= " from argus ";
	
#if(param('ids')){
	#   $query .= ", ids ";
#}
	$query .= " left join os          on argus.client_os_id     = os.os_id               and argus.sensor_id  = os.sensor_id";
	$query .= " left join ids         on ids.argus_id           = argus.argus_id         and argus.sensor_id  = ids.sensor_id";
	$query .= " left join ids_sig     on ids.sig_id             = ids_sig.ids_sig_id     and argus.sensor_id  = ids_sig.sensor_id ";
	$query .= " left join sys_socket  on argus.argus_id         = sys_socket.argus_id    and argus.sensor_id  = sys_socket.sensor_id ";
	$query .= " left join process     on sys_socket.process_id  = process.process_id     and argus.sensor_id  = process.sensor_id ";
	$query .= " where ";
	
	
	
	$query2 = "select COUNT(DISTINCT(argus.argus_id)) from argus where ";
	
	
	my $q = new CGI;
	Walleye::Util::scrub_cgi(\$q);
	$query  .= Walleye::Util::gen_flow_query_filter($q,\@bindings,\$and,   defined param('all_times'));
	$query2 .= Walleye::Util::gen_flow_query_filter($q,\@bindings2,\$and2, defined param('all_times'));
	
	
#print "$query<p>$query2";
	
	$query .= "group by  argus.argus_id, ids_sig.ids_sig_id  order by  start_sec ";





	#---- get total number of pages and rows, if using pager

	if($query2){
	    $sql = $Walleye::Util::dbh->prepare($query2);
	    $sql->execute(@bindings2);
	    $ref = $sql->fetchall_arrayref();
	    if($$ref[0][0]){
		$total_pages = int($$ref[0][0] / $limit)+1;
	    }else{
		$total_pages = 1;
	    }
	}


	if(param('page') && param('page') > 0 && param('page') <= $total_pages){
	    $page = param('page');
	    $start = ($page -1 ) * $limit;
	}else{
	    param('page',1);
	    $page = 1;
	    $start = 0;
	}


	
	$query .= " limit $start,$limit  ";
	
	
	$sql = $Walleye::Util::dbh->prepare($query);
	$sql->execute(@bindings);
	$ref = $sql->fetchall_arrayref();
    }
#print "$query<hr>";
#print "$start_time<br>$end_time<br>\n";
    
#----- put flow data into hash
    foreach $line(@$ref){
	if(!$start_time){
	    my @time = gmtime($$line[0]);
	    $start_time = gmtime($$line[0]);
	    
	    #$hour = $time[2]; 
	    #$day  = $time[3];
	    #$month= $time[4] + 1;
	    #$year = 1900 + $time[5];
	}
	
	
	$lut{$$line[14]}{$$line[3]}{"start"}     = $$line[0];
	$lut{$$line[14]}{$$line[3]}{"et"}        = $$line[1];
	$lut{$$line[14]}{$$line[3]}{"start_txt"} = $$line[2];
	$lut{$$line[14]}{$$line[3]}{"proto"}     = $$line[4];
	$lut{$$line[14]}{$$line[3]}{"sip"}       = $$line[5];
	$lut{$$line[14]}{$$line[3]}{"sport"}     = $$line[6];
	$lut{$$line[14]}{$$line[3]}{"os"}        = $$line[7];
	$lut{$$line[14]}{$$line[3]}{"dip"}       = $$line[8];
	$lut{$$line[14]}{$$line[3]}{"dport"}     = $$line[9];
	$lut{$$line[14]}{$$line[3]}{"spkts"}     = $$line[10];
	$lut{$$line[14]}{$$line[3]}{"sbytes"}    = $$line[11];
	$lut{$$line[14]}{$$line[3]}{"dpkts"}     = $$line[12];
	$lut{$$line[14]}{$$line[3]}{"dbytes"}    = $$line[13];
	$lut{$$line[14]}{$$line[3]}{"sensor"}    = $$line[14];
	
	if($$line[15]){
	    #print $$line[15] ." (".$$line[18].") ".$$line[17]."<br>\n";	    
	    $lut{$$line[14]}{$$line[3]}{"ts"}{$$line[16]}{"events"}{$$line[15]}{"count"} = $$line[20];
	    $lut{$$line[14]}{$$line[3]}{"ts"}{$$line[16]}{"events"}{$$line[15]}{"dir"}   = $$line[19];
	    $lut{$$line[14]}{$$line[3]}{"ts"}{$$line[16]}{"events"}{$$line[15]}{"sig"}   = $$line[18];
	    $lut{$$line[14]}{$$line[3]}{"ts"}{$$line[16]}{"events"}{$$line[15]}{"pri"}   = $$line[17];
	}
	$lut{$$line[14]}{$$line[3]}{"argus_dir"}       = $$line[21];
	$lut{$$line[14]}{$$line[3]}{"argus_status"}    = $$line[22];
	
	$lut{$$line[14]}{$$line[3]}{"pid"}             = $$line[23];
	$lut{$$line[14]}{$$line[3]}{"process_id"}      = $$line[24];
	
    }
    

    
    
    
    
#------ create html tables for each connection --------------------------------------------------------------------
    my $con;
    my $flow;
    
    my $et;
    my $start_txt;
    my $is_client;
    
    my $proto;
    my $proto_txt;
    
    my $sip;
    my $dip;
    
    my $sport;
    my $dport;
    
    
    my $os_c; 
    my $os_s;
    my $pkts_c;
    my $kb_c;
    my $pkts_s;
    my $kb_s;
    my $a_dir;
    my $a_status;
    
    my $ids_table;
    my $con_table;
    my $flow_table;
    my $nav_table;
    
    
    my $haveids = 0;
    my $counter;
    
    my $ids_color;

    my %html;


    my $sport_txt;
    my $dport_txt;


    my $id;
    my $sig;
    my $ts;
    my $pri;
    my $pid;
    
    my $pid_txt;

    my $dir;
    foreach $sensor(sort keys %lut){
	foreach $con(sort keys %{$lut{$sensor}}){
	   
	    next if($con == 0);
	    

	    $et        = $lut{$sensor}{$con}{"et"};
	    $start_txt = $lut{$sensor}{$con}{"start_txt"};
	    $sip       = $lut{$sensor}{$con}{"sip"};
	    $dip       = $lut{$sensor}{$con}{"dip"};
	    
	    $proto     = $lut{$sensor}{$con}{"proto"};
	    $sport     = $lut{$sensor}{$con}{"sport"};
	    $dport     = $lut{$sensor}{$con}{"dport"};
	    $pkts_c    = $lut{$sensor}{$con}{"spkts"};
	    $kb_c      = int($lut{$sensor}{$con}{"sbytes"} / 1000);
	    $os_c      = $lut{$sensor}{$con}{"os"};
	    $pkts_s    = $lut{$sensor}{$con}{"dpkts"};
	    $kb_s      = int($lut{$sensor}{$con}{"dbytes"} / 1000);

	    $a_dir     = $lut{$sensor}{$con}{"argus_dir"};
	    $a_status  = $lut{$sensor}{$con}{"argus_status"};

	    $pid       = $lut{$sensor}{$con}{"pid"};

	    $start     = $lut{$sensor}{$con}{"start"}      ?  $lut{$sensor}{$con}{"start"} : 0;
	    $process_id= $lut{$sensor}{$con}{"process_id"} ?  $lut{$sensor}{$con}{"process_id"} : 0;
	    
	    
	    
	    if(!defined $os_c){
		$os_c = "os unkn";
	    }else{
	        $os_c =~ s/\W+//g;
            }
	    
	    if(!$os_s){
		$os_s = " --- ";
	    }
       		

	   

	    
	    $et = sprintf("%02d",int($et/3600)) .":".sprintf("%02d",int($et/60) % 60).":".sprintf("%02d",int($et%60));

										     
	    $sport_txt = $Walleye::Util::port_lut{$Walleye::Util::proto_lut{$proto}}{$sport} ? $Walleye::Util::port_lut{$Walleye::Util::proto_lut{$proto}}{$sport} : $sport;
	    $dport_txt = $Walleye::Util::port_lut{$Walleye::Util::proto_lut{$proto}}{$dport} ? $Walleye::Util::port_lut{$Walleye::Util::proto_lut{$proto}}{$dport} : $dport;
	    
	    
	    $proto_txt = $Walleye::Util::proto_lut{$proto};
	    
	   
	    $ids_table = new HTML::Table(-border=>0,-padding=>0,-spacing=>0);
	    $flow_table = new HTML::Table(-border=>0,-padding=>0,-spacing=>0);	



	    

	    $flow_table->addRow(
				"<font size=-2 color=000000>".$start_txt."</font>",
				"",
				"<font size=-2 color=000000>$et</font>",
				"",
				#"<font size=-2 color=000000>ID: <a href=\"pcap_api.pl?sensor=".$sensor.";con_id=".$con."\">".$con."</font>",
				);

	    if($process_id > 0){
		$pid_txt =  "<font size=-2><b><a target=\"_top\" href=\"?act=tree;sensor=$sensor;process_id=$process_id\">PID: $pid</a></b></font>";
	    }else{
		$pid_txt = "";
	    }
	       $flow_table->addRow(
                                "$pid_txt",
                                "<font size=-1><b><a target=\"new\" href=\"?act=hd&ip=$sip\">".inet_ntoa(pack("N",$sip))."</a></b></font>",
                                "<font size=-1 color=777700>$a_dir</font>",
                                "<font size=-1><b><a target=\"new\" href=\"?act=hd&ip=$dip\">".inet_ntoa(pack("N",$dip))."</a></b></font>",
                            );


	    $flow_table->addRow(
				"<font color=006600><b>$proto_txt<b></font>",
				"<font color=006600><b>".$sport_txt."</b></font>",
				"<font size=-2 color=008888>$kb_c kB </font><font size=-2 color=880000> $pkts_c pkts --\></font>",
				"<font color=006600><b>".$dport_txt."</b></font>"
				);
	    $flow_table->addRow(
				"<font size=-2 color=777700>$a_status</font>",
				"<font size=-2 color=777700>$os_c</font>",
				"<font size=-2 color=008888>\<--$kb_s kB </font><font size=-2 color=880000>$pkts_s pkts</font>",
				"<font size=-2 color=777700>$os_s</font>",
				);

	    $flow_table->setCellColSpan(1,1,2);
	    #$flow_table->setCellRowSpan(2,1,2);
	    
	    $flow_table->setColWidth(1,75);
	    $flow_table->setColAlign(1,"LEFT");
	    
	    $flow_table->setColWidth(2,75);
	    $flow_table->setColAlign(2,"CENTER");
	    
	    
	    $flow_table->setColWidth(3,100);
	    $flow_table->setCellAlign(1,3,"CENTER");
	    $flow_table->setCellAlign(2,3,"CENTER");
	    $flow_table->setCellAlign(3,3,"LEFT");
	    $flow_table->setCellAlign(4,3,"RIGHT");
	  
	    
	    $flow_table->setColWidth(4,75);
	    $flow_table->setColAlign(4,"CENTER");
	    

	
	    $haveids = 0;
	    my $count;
	    #----- The flow is set now we need to add rows to the IDS table
	    foreach $ts (sort {$a <=> $b}keys %{$lut{$sensor}{$con}{"ts"}}){
		foreach $id (sort {$a <=> $b}keys %{$lut{$sensor}{$con}{"ts"}{$ts}{"events"}}){
	
		    $pri = $lut{$sensor}{$con}{"ts"}{$ts}{"events"}{$id}{"pri"};
		    $sig = $lut{$sensor}{$con}{"ts"}{$ts}{"events"}{$id}{"sig"};
		    $count =  $lut{$sensor}{$con}{"ts"}{$ts}{"events"}{$id}{"count"};
		    
		    if(!$sig){
			$sig = "unknown signature";
		    }
		    
		    #print "hmm...".$lut{$sensor}{$con}{"ts"}{$ts}{"events"}{$id}{"dir"}."<br>\n";
		    if($lut{$sensor}{$con}{"ts"}{$ts}{"events"}{$id}{"dir"} eq "CLIENT"){
			$dir = " -$count-> ";
		    }else{
			$dir = " <-$count- ";
		    }
		    
		    $haveids++;
		    
		    
		    
		    $ids_table->addRow(
				       "<font size=-1 color=00006a><b>$dir</b></font>",
				       #"<font size=-2 color=550055>".gmtime($ts)."</font>",
				       #$ts,
				       #$id,
				       "<font size=-1 color=cc0000>$sig</font>"
				       );
		} 
	    }
	
	    if($haveids){
		$ids_table->setColWidth(1,10);
		$ids_table->setColAlign(1,"LEFT");
		
		#$ids_table->setColWidth(2,100);
		#$ids_table->setColAlign(2,"LEFT");
		
		
		$ids_table->setColWidth(3,250);
		$ids_table->setColAlign(3,"LEFT");
		
		
	    }
		
	    #----- add the sub tables to the connection row.
	

	    $html{$start}{$sensor}{$con}{$process_id} = new HTML::Table(
						  -border=>0,
						  -spacing=>0,
						  -padding=>0,
						  );
	    $html{$start}{$sensor}{$con}{$process_id}->addRow( 
				     $flow_table->getTable,
				     $ids_table->getTableRows ? $ids_table->getTable : " "
				     );
	  
	    $html{$start}{$sensor}{$con}{$process_id}->setColClass(1,"et_flow");
	    $html{$start}{$sensor}{$con}{$process_id}->setColClass(2,"et_ids");
	   
	
	}
    }
    
    my  $ctable = new HTML::Table(
				 -class=>'et',
				 -border=>0,
				 -spacing=>0,
			         -padding=>0,			
				 );

    $counter = 1;
    if($total_pages > 1){
      $ctable->addRow(Walleye::Util::result_pager($page,$total_pages));
      $ctable->setCellColSpan(1,1,2);
      $ctable->setCellClass(1,1,'aggregate_flow_index');
      $counter++;
    }
  
    my $select;
    foreach $start(sort {$a <=> $b } keys %html){
	foreach $sensor(sort {$a <=> $b} keys %{$html{$start}}){
	    foreach $con(sort {$a <=> $b} keys %{$html{$start}{$sensor}}){
		foreach $process_id(sort {$a <=> $b} keys %{$html{$start}{$sensor}{$con}}){
		    #----- proto number to txt mapping.
		    #----- port to service mapping?
		    #----- dns mapping?
		    $select = "";
		    if($process_id != 0){
			$select  .= "<br><a target=\"_top\" href=\"?act=tree;sensor=$sensor;process_id=$process_id\" >";
			$select  .= "<img border=0 title=\"Show me the Process Tree\" src=\"icons/sbk.png\"\></a>";
			$select  .= "<br><a target=\"_top\" href=\"?act=ct;sensor=$sensor;process_tree_con=$con;all_times=1\" >";
			$select  .= "<img border=0 title=\"Show me the related Flows\" src=\"icons/flow.png\"\></a>";
		    }
		    $select  .= "<br><a href=\"?act=flowdf;sensor=$sensor;con_id=$con\" >";
                    $select  .= "<img border=0 title=\"Examine this flow\" src=\"icons/detail.png\"\></a>";
		    $select  .= "<br><a href=\"pcap_api.pl?sensor=$sensor;con_id=$con\" >";
		    $select  .= "<img border=0 title=\"Download the coresponding packet capture\" src=\"icons/pcap.png\"\></a>";
		    $ctable->addRow($select,$html{$start}{$sensor}{$con}{$process_id}->getTable);
		    
		    if($counter % 2){
			$ctable->setLastRowClass("et_even");
		    }else{
			$ctable->setLastRowClass("et_odd");
		    }
		
		    if(defined(param('process_tree')) && $process_id ==  param('process_tree')){
			$ctable->setCellClass($counter,1,"et_hi");
		    }elsif($process_id){
			$ctable->setCellClass($counter,1,"et_med");
		    }else{
			$ctable->setCellClass($counter,1,"et_index");
		    }

		    $counter++;
		}
	    
	    }
	}
    }

   
    #$ctable->setColClass(1,"et_index");

    return $ctable->getTable;
}
