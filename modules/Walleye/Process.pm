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
#----- Process  View
#-----
#----- Version:  $Id: Process.pm 1763 2005-07-15 17:25:12Z cvs $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  


package Walleye::Process;
use strict;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;
use Date::Calc qw(:all);
use HTML::Table;
use HTML::Entities;
use HTML::CalendarMonthSimple;
use CGI qw/:standard/;
use Socket;

use Walleye::Util;



#----- Module stuff

require Exporter;
our @ISA=("Exporter");
#our @EXPORT = qw (get_frame get_ps get_opened_files get_fd_sum get_fd_details );
	    
#-----





sub htmlify_log{
  my $log = shift;
    
  $log = encode_entities($log);

  $log =~ s/&\#27;\[A/<font color=\"orange\">[U-ARROW] <\/font>/g;
  $log =~ s/&\#27;\[B/<font color=\"orange\">[D-ARROW] <\/font>/g;
  $log =~ s/&\#27;\[C/<font color=\"orange\">[R-ARROW] <\/font>/g;
  $log =~ s/&\#27;\[D/<font color=\"orange\">[L-ARROW] <\/font>/g;
  $log =~ s/&\#27;\[5~/<font color=\"orange\">[PAGE-U] <\/font>/g;
  $log =~ s/&\#27;\[6~/<font color=\"orange\">[PAGE-D] <\/font>/g;
  $log =~ s/&\#127;/<font color=\"orange\">[DEL] <\/font>/g;
  $log =~ s/&\#8;/<font color=\"orange\">[BS] <\/font>/g;
  $log =~ s/&\#27;/<font color=\"orange\">[ESC] <\/font>/g;
	
  return $log;
}

sub sanitize_data{
  my $log = shift;

  #----- map control characters
  $log =~ s/\x1b\[A/[U-ARROW]/g;
  $log =~ s/\x1b\[B/[D-ARROW]/g;
  $log =~ s/\x1b\[C/[R-ARROW]/g;
  $log =~ s/\x1b\[D/[L-ARROW]/g;
  $log =~ s/\x1b\[3~/[DEL]/g;
  $log =~ s/\x1b\[5~/[PAGE-U]/g;
  $log =~ s/\x1b\[6~/[PAGE-D]/g;
  $log =~ s/\x7f/[BS]/g;
  $log =~ s/\x1b/[ESC]/g;

  #----- scrub other nonascii values
  $log =~ s/[^\x20-\x7e]//g;

  $log = encode_entities($log);


  return $log;
}

sub get_fd_details{

    my $table = new HTML::Table(
				-class=>'body',
				-width=>'800'
				);

    my @bindings;

    my $query = "select DATE_FORMAT(FROM_UNIXTIME(pcap_time),\"%H:%I:%S\"),  data from sys_read where ";
    $query .= " process_id = ? and sensor_id = ? and inode = ? order by counter";

    push(@bindings,param("process_id"));
    push(@bindings,param("sensor"));
    push(@bindings,param("inode"));

    my $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute(@bindings);

    my $ref = $sql->fetchall_arrayref();

    my $x;
   
    my $log;
    my $ts;
    foreach (@$ref){
	$ts   = $$_[0];

	if($$_[1] =~ m/\n|\r/){
	  $table->addRow($ts,htmlify_log($log));
	  if($x++ % 2){
	      $table->setLastRowClass("et_even");
	  }else{
	      $table->setLastRowClass("et_odd");
	  }

	  $log = "";
       }else{
	 $log .= $$_[1];
       }

    }
    
    $table->addRow($ts,sanitize_data($log));
    if($x++ % 2){
      $table->setLastRowClass("et_even");
    }else{
      $table->setLastRowClass("et_odd");
    }

    $table->setColClass(1,"sbk_ts");
    $table->setColClass(2,"sbk_log");

    return $table->getTable;
}



#--- gen_fd_details: generate a processes file descriptor summary
sub get_fd_sum{
   
    my @bindings;

    my $table = new HTML::Table(
			
				-class=>'body',
				);

    my $query  = "select filed, inode,  FROM_UNIXTIME(MIN(pcap_time)), uid, SUM(length), ROUND(AVG(length)) from sys_read where process_id = ? and sensor_id = ?  ";
    
    push(@bindings,param("process_id"));
    push(@bindings,param("sensor"));
    
    if(param('kso')>0){
	$query .= " and length < 10 ";
    }

    $query .= " group by filed, inode, uid  order by filed, inode,  counter";

    
    my $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute(@bindings);
    
    my $ref = $sql->fetchall_arrayref();

    

    $table->addRow("Read Details", "FD","Inode", "Time", "UID", "Bytes Read", "Ave Read Len");
    
    my $q = new CGI;
    $q->param('act','pd');

    my $x;
    foreach (@$ref){
	$q->param('inode',$$_[1]);
       
	$table->addRow(
		       "<a target=\"_top\" href=\"".$q->url(-query=>1)."\"><img border=0 src=\"icons/detail.png\"/></a>",
		       $$_[0],
		       $$_[1],
		       $$_[2],
		       $$_[3],
		       $$_[4],
		       $$_[5]
		       );

	if($x++ % 2){
	    $table->setLastRowClass("et_even");
	}else{
	    $table->setLastRowClass("et_odd");
	}
    }

   
    $table->setColClass(1,"sbk_other");
    $table->setColClass(2,"sbk_other");
    $table->setColClass(3,"sbk_other");
    $table->setColClass(4,"sbk_other");
    $table->setColClass(5,"sbk_other");
    $table->setColClass(6,"sbk_other");
    $table->setColClass(7,"sbk_other");
  
    
    
    $table->setCellClass(1,1,"sum_head_t");
    $table->setCellClass(1,2,"sum_head_t");
    $table->setCellClass(1,3,"sum_head_t");
    $table->setCellClass(1,4,"sum_head_t");
    $table->setCellClass(1,5,"sum_head_t");
    $table->setCellClass(1,6,"sum_head_t");
    $table->setCellClass(1,7,"sum_head_t");

    return $table->getTable;

}


sub get_opened_files{
        
    my $table = new HTML::Table(
			        -class=>'body'
				);
    
    
    #------ get files touched by process
   
    
    my $query  = "select pcap_time,filename, uid, inode, filed from sys_open where process_id = ? and sensor_id = ? order by pcap_time";
    my $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute(param("process_id"),param("sensor"));
    my $ref = $sql->fetchall_arrayref();
    

    my $file_table = new HTML::Table();
   
    $file_table->addRow("Timestamp","File Name","User ID","Inode","File Descr");
    

  
    my $counter;
    foreach (@$ref){
	$file_table->addRow(scalar(gmtime($$_[0])),$$_[1],$$_[2],$$_[3],$$_[4]);	
	 $counter++;

	if($counter % 2){
	    $file_table->setLastRowClass("et_even");
	}else{
	    $file_table->setLastRowClass("et_odd");
	}
    }
    
    $file_table->setColClass(1,"sbk_ts");
    $file_table->setColClass(2,"sbk_fname");
    $file_table->setColClass(3,"sbk_other");
    $file_table->setColClass(4,"sbk_other");
    $file_table->setColClass(5,"sbk_other");

   
    $file_table->setCellClass(1,1,"sum_head_t");
    $file_table->setCellClass(1,2,"sum_head_t");
    $file_table->setCellClass(1,3,"sum_head_t");
    $file_table->setCellClass(1,4,"sum_head_t");
    $file_table->setCellClass(1,5,"sum_head_t");

    return $file_table->getTable;



}

sub get_ps{
    my $sum = new HTML::Table(
				-class=>'body',
				);

    my $query = " select  process.src_ip, process.pid,  process.pcap_time_min, process.pcap_time_max from process where process.process_id = ? and process.sensor_id = ? ";
    my $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute(param("process_id"),param("sensor"));

    my $ref = $sql->fetchall_arrayref();

    $sum->addRow("Process Summary");
    
    
    my $q;
    my $row;
    foreach (@$ref){
	$q = new CGI;
	$q->param("act","ct");
	
	$sum->addRow("Host IP:",
		     inet_ntoa(pack('N',$$_[0])),
		     "View this process's connections:",
		     "<a class=\"none\" target=\"_top\" href=\"".$q->url(-query=>1)."\"><img border=0  title=\"Show me this process's Flows\" src=\"icons/flow.png\"/></a>");
	
	$q->param("act","ct");
	$q-> param("process_tree",param("process_id"));
	$q->delete("process_id");
	$sum->addRow("PID:",$$_[1],
		     "View all connections from this process tree:",
		     "<a class=\"none\" target=\"_top\" href=\"".$q->url(-query=>1)."\"><img border=0   title=\"Show me the related Flows\" src=\"icons/flow.png\"/></a>");

	$q->param("act","tree");
	$q->param("process_id",$q->param("process_tree"));
	$q->delete("process_tree");
	$sum->addRow("First:",
		     scalar(gmtime($$_[2])),
		     "View Process Tree for this Process:",
		     "<a class=\"none\" target=\"_self\" href=\"".$q->url(-query=>1)."\"><img border=0 title=\"Show me the related Process Tree\"  src=\"icons/sbk.png\"/></a>");
	$q->param("act","pd");
	$sum->addRow("Last:",
		     scalar(gmtime($$_[3])),
		     "View Details for this Process:",
		     "<a class=\"none\" target=\"_self\" href=\"".$q->url(-query=>1)."\"><img border=0 title=\"Show me the details\"  src=\"icons/detail.png\"/></a>");

		  
    }
   

    $query = "select command.name  ";
    $query .= " from process, process_to_com, command ";
    $query .= " where process.process_id = process_to_com.process_id and process.sensor_id = process_to_com.sensor_id ";
    $query .= " and  process_to_com.command_id = command.command_id and process_to_com.sensor_id = command.sensor_id ";
    $query .= " and  process.process_id = ? and process.sensor_id = ? ";
    
    $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute(param("process_id"),param("sensor"));

    $ref = $sql->fetchall_arrayref();

    $sum->addRow("Commands:","");


    foreach (@$ref){
	$sum->addRow("",$$_[0]);		  
    }

    
    $sum->setColClass(1,"sum_head_l");
    $sum->setColClass(2,"sum_body");
    $sum->setColClass(3,"sum_head_l");
    $sum->setColClass(4,"sum_body");

    $sum->setCellColSpan(1,1,4);
    $sum->setCellClass(1,1,"sum_h");
    

    return $sum->getTable;
    
}



#--- gen_pd:  generate process details
sub get_frame{
    
    my $q = new CGI;
    
    #----- render this pig
    my $table = new HTML::Table(
				-class=>"et",
				-padding=>1,
				-border=>1,
				);

    $table->addRow(get_ps($q->param('process_id')));
    $q->param('act','off');
    $table->addRow("Opened Files\n");
    $table->addRow("<iframe  width=\"100%\" height=\"100\" src=\"".$q->url(-query=>1)."\"></iframe>");
  
    $q->param('act','fdf');
    $table->addRow("Read Activity\n");
    $table->addRow("<iframe  width=\"100%\" height=\"100\" src=\"".$q->url(-query=>1)."\"></iframe>");

    $q->param('act','fdd');
    $table->addRow("Read Details\n");
    $table->addRow("<iframe  width=\"100%\" height=\"200\" src=\"".$q->url(-query=>1)."\"></iframe>");


    $table->setCellClass(2,1,"sum_h");
    $table->setCellClass(3,1,"et_fun");
    $table->setCellClass(4,1,"sum_h");
    $table->setCellClass(5,1,"et_fun");
    $table->setCellClass(6,1,"sum_h");
    $table->setCellClass(7,1,"et_fun");
  
    return $table->getTable;
}
