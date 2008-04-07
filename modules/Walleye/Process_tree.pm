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
#----- Process Tree View
#-----
#----- Version:  $Id: Process_tree.pm 4227 2006-08-21 16:52:12Z cviecco $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  


package Walleye::Process_tree;
use strict;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;
use Date::Calc qw(:all);
use HTML::Table;
use HTML::Entities;
use HTML::CalendarMonthSimple;
use CGI qw/:standard/;
use File::Temp "tempfile";
use Socket;

use Walleye::Util;
use Walleye::Process;



#----- Module stuff

require Exporter;
our @ISA=("Exporter");
#our @EXPORT = qw (get_table get_frame);
	    
#-----

my $dotbin      = "/usr/bin/dot";

sub gen_dot_graph{
    my $t_ref         = shift;
    my $title         = shift;
    my $start_point   = shift;
    my $sensor        = shift;

    my @results;
    my $query;
    my $target  = Walleye::Util::array_to_in($t_ref,0);

    #------ fun
    my $comstr;
    my $pidstr;
    my $start;
    my $stop;

    my $label;
    my $descr;
    my $url;

    my %lut;
    my %socket;
    my %ids;

    my %rank;
    my $shape;
    my $fillcolor;
    my $color;


    #------ get basic process info
    $query  = "select process.process_id, process.pid, command.name, process.time_min, process.time_max,  process.src_ip, process.src_ip ";
    $query .= "from process  ";
    $query .= " left join process_to_com on process_to_com.process_id = process.process_id  and process_to_com.sensor_id = process.sensor_id ";
    $query .= " left join command on process_to_com.command_id = command.command_id  and process_to_com.sensor_id = command.sensor_id";
    $query .= " where process.process_id in $target ";
    $query .= " and process.sensor_id = ? ";
    $query .= "  order by process.time_min,process.time_max, process.pid";

    #print "<br>$query<br>";

    my $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute($sensor);

    my $data_ref    = $sql->fetchall_arrayref();
    my $foo;


    my $base_query;
    $base_query  = "select event.cid, event.sid , signature.sig_name, ip_dst , tcp_dport, event.timestamp ";
    $base_query .= " from event, iphdr, tcphdr, signature ";
    $base_query .= " where and event.sensor_id = ? ";
    $base_query .= " iphdr.cid  = event.cid and iphdr.sensor_id = event.sensor_id and ";
    $base_query .= " iphdr.sid  = event.sid  and ";
    $base_query .= " event.signature = signature.sig_id and  event.sensor_id = signature.sensor_id and ";
    $base_query .= " tcphdr.cid = event.cid and tcphdr.sensor_id = event.sensor_id and  ";
    $base_query .= " tcphdr.sid = event.sid and ";

   
    
    
    my $counter = 0;
    my $sock_counter = 0;
    my $ids_counter = 0;
   
    my $ids_info;
    foreach $foo(@$data_ref){

        $lut{$$foo[0]}{"command"}{$$foo[2]}++;
        $lut{$$foo[0]}{"pid"}      = $$foo[1];
        $lut{$$foo[0]}{"time_min"} = $$foo[3];
        $lut{$$foo[0]}{"time_max"} = $$foo[4];
	if(!defined $lut{$$foo[0]}{"order"}){
	    $lut{$$foo[0]}{"order"} = $counter++;
	}

	$lut{$$foo[0]}{"host_id"} = $$foo[5];
	$lut{$$foo[0]}{"host_ip"} = $$foo[6];

	if($$foo[6] && $$foo[7] && $$foo[8] &&  $$foo[9] && $$foo[10] && $$foo[11] && $$foo[12] && $$foo[8] == 6){
	    #------- we have some socket data
	    $lut{$$foo[0]}{"num_sock"}++;
	    
	    $socket{$$foo[0]}{$$foo[6]}[0] = $$foo[7];
	    $socket{$$foo[0]}{$$foo[6]}[1] = $$foo[8];  
	    $socket{$$foo[0]}{$$foo[6]}[2] = $$foo[9];  #--- localip
	    $socket{$$foo[0]}{$$foo[6]}[3] = $$foo[10];
	    $socket{$$foo[0]}{$$foo[6]}[4] = $$foo[11];
	    $socket{$$foo[0]}{$$foo[6]}[5] = $$foo[12];	    
	     
	    #------- ignoring dimention of time for now

	    if($sock_counter > 0){
		$query .= " or ";
	    }
	    $sock_counter++;
	    
	    $query = $base_query;
	    $query .= " (  ip_proto=$$foo[8] and ( ";
	    $query .= " (ip_src = $$foo[9] and tcp_sport = $$foo[10] and ip_dst = $$foo[11] and tcp_dport = $$foo[12] ) ";
	    $query .= " or ";
	    $query .= " (ip_dst = $$foo[9] and tcp_dport = $$foo[10] and ip_src = $$foo[11] and tcp_sport = $$foo[12] ) ";
	    $query .= " ) ) order by event.timestamp ";
 
	    print "<br>$query<br>";

	    $sql  = $Walleye::Util::dbh->prepare($query);
	    $sql->execute($sensor);
    
	    $data_ref = $sql->fetchall_arrayref;
	    
	    foreach $ids_info(@$data_ref){
		$ids_counter++;
		#print " $$foo[0] -> $$foo[6] -> $$ids_info[1] == $$ids_info[2]\n";
		$socket{$$foo[0]}{$$foo[6]}[6]{$$ids_info[0]}{$$ids_info[1]} = $$ids_info[2];
		$ids{$$ids_info[0]}{$$ids_info[1]}{"signature"} = $$ids_info[2];
		$ids{$$ids_info[0]}{$$ids_info[1]}{"timestamp"} = $$ids_info[5];
		$ids{$$ids_info[0]}{$$ids_info[1]}{"order"}     = $ids_counter;


		if($$foo[9] == $$ids_info[3]){
		    #---- ok the process was the target of the event
		    $ids{$$ids_info[0]}{$$ids_info[1]}{"process_id"}{$$foo[0]} = 1;
		}else{
		    $ids{$$ids_info[0]}{$$ids_info[1]}{"process_id"}{$$foo[0]} = 0;
		}
	    }
	}
	    
    }

   
    #----- get process uid info ------------------------
    $query  = "select DISTINCT process.process_id, sys_read.uid ";
    $query .= "from process, sys_read ";
    $query .= "where process.process_id = sys_read.process_id and process.sensor_id = sys_read.sensor_id ";
    $query .= " and process.process_id in $target and process.sensor_id = ? ";

    $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute($sensor);

    $data_ref = $sql->fetchall_arrayref;

    foreach $foo(@$data_ref){
        $lut{$$foo[0]}{"uid"}{$$foo[1]} = 1;
    }


    #----- get process uid info from sys_socket------------------------
    $query =  "select DISTINCT process.process_id,  sys_socket.uid ";
    $query .= "from process, sys_socket ";
    $query .= "where process.process_id = sys_socket.process_id  and process.sensor_id = sys_socket.sensor_id ";
    $query .= " and process.process_id in $target and process.sensor_id = ?";

    $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute($sensor);

    $data_ref = $sql->fetchall_arrayref;

    foreach $foo(@$data_ref){
        $lut{$$foo[0]}{"uid"}{$$foo[1]} = 1;
    }

   
    
    print DOT "digraph proc_tree{\n";
    print DOT "    nodesep=.25;\n";
    print DOT "    ranksep=.75;\n";
    print DOT "    label=\"$title\"";
    print DOT "    size=\"1024,768\";\n";
    print DOT "    center=true;\n";
    print DOT "    bgcolor=\"#f5f5e5\"\n";
    print DOT "    color=grey;\n";
    print DOT "    ratio=compress\n";
    
  
    #----- print details for each process node ---------------
    print DOT "    node [fontcolor=black, fontsize=9,  shape=box,  height=.6, width=1.5  ];\n";
    my $tmp;
    
    my $proc_color;

    foreach $foo(sort {$lut{$a}{"order"} <=> $lut{$b}{"order"}} keys %lut){
	
	if($foo == $start_point){
	    #print "come on folks\n";
	    $shape = "shape=diamond";
	}else{
	    $shape = "shape=rectangle";
	}
	    


        if($lut{$foo}{"uid"}{"0"}){
	    $proc_color = "yellow";
	}else{
	    $proc_color = "cyan";
	}
	$color = "fillcolor=$proc_color";
	

	$label  = "< <table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"100%\">";
	$label .= " <tr><td border=\"1\" colspan=\"2\" align=\"center\" bgcolor=\"white\">".$foo." ".$lut{$foo}{"order"}."</td></tr>";
	$label .= "<tr><td border=\"1\" width=\"25%\" align=\"right\" bgcolor=\"$proc_color\">Host:</td><td border=\"1\" width=\"75%\" align=\"center\" bgcolor=\"white\">";
	$label .= inet_ntoa(pack('N',$lut{$foo}{"host_ip"}))."</td></tr>";	
	$label .= "<tr><td border=\"1\" width=\"25%\" align=\"right\" bgcolor=\"$proc_color\">PID:</td><td border=\"1\" width=\"75%\" align=\"center\" bgcolor=\"white\">".$lut{$foo}{"pid"}."</td></tr>";	


	$label .= "<tr><td border=\"1\" colspan=\"2\"  align=\"center\" bgcolor=\"white\">";
	foreach $tmp (keys %{$lut{$foo}{"command"}}){
	    $label .= " $tmp ";

	}   
	$label .= "</td></tr>";
	$label .= "</table> >";
	

	$descr =  gmtime($lut{$foo}{"time_min"}) ." to ".gmtime($lut{$foo}{"time_max"});

        print DOT "      $foo [tooltip=\"$descr\", $color, $shape, label=$label, style=filled, URL=\"./walleye.pl?act=tree&process_id=$foo;sensor=$sensor\" target=\"_top\"];\n";
    }



    #------ get parent child relations -------------------------
    $query =  "select process_tree.parent_process,  process_tree.child_process ";
    $query .= "from process_tree ";
    $query .= "where (process_tree.parent_process in $target ";
    $query .= " or   process_tree.child_process  in $target) and  ";
    $query .= " process_tree.sensor_id = ?";

    $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute($sensor);

    $data_ref = $sql->fetchall_arrayref;

    print DOT "    node [ fontsize=6, shape=plaintext, height=.25, width=.5  ];\n";
    #----- print link information ----------------------------
    foreach $foo(@$data_ref){
	#--- only add link if both sides are described above
	if($lut{$$foo[0]} && $lut{$$foo[1]}){
	    print DOT"      $$foo[0] -> $$foo[1] [ style=bold]; \n";
	}
    }


    #----- print details for each related IDS event ---------
    #----- this seems broken
    if(!$color){
	$color = "color=white";
    }
    print DOT "    node [ fontsize=8, $color, shape=rectangle,  fontcolor=black,  ];\n";

    my $cid;
    my $sid;
    my $sig;
    my $str;
    my $pid;
    my $class;
    foreach $cid(keys %ids){
	foreach $sid(keys %{$ids{$cid}}){

	    ($class,$sig) = split(' ',$ids{$cid}{$sid}{"signature"},2);
	    $label  = "< <table border=\"1\" cellpadding=\"1\" cellspacing=\"0\" width=\"100%\">";
	    $label .= "<tr><td rowspan=\"2\" bgcolor=\"red\" width=\"20%\" align=\"center\">".$ids{$cid}{$sid}{"order"}."</td>";   
	    $label .= "<td bgcolor=\"white\"  align=\"left\">$class</td></tr>";
	    $label .= "<tr><td bgcolor=\"white\"  align=\"left\">".$sig."</td></tr>";
	    $label .= "</table> >";
	    $descr = "CID:$cid  SID:$sid  Timestamp:". gmtime($ids{$cid}{$sid}{"timestamp"});
	    $url   = "ids_details?cid=$cid,sid=$sid";
	    $foo = $cid.".".$sid;
	    print DOT "   $foo [tooltip=\"$descr\",  label=$label,  URL=\"$url\"];\n";
	  
	    foreach $pid (keys %{$ids{$cid}{$sid}{"process_id"}}){

		if($ids{$cid}{$sid}{"process_id"}{$pid} == 1){
		    print DOT "   $foo -> $pid [color=red, arrowhead=vee];\n";
		}else{
		   print DOT "   $pid -> $foo [color=red, arrowhead=vee];\n";
	       } 
	    }
	}
    }
    print DOT "}\n";
}




sub get_table{
  my $table = new HTML::Table(
			      -class=>'body',
			      );
  my $q = new CGI;

  if(!$q->param('process_id')){
      #--- we need to figure out the process_id from the con_id
      my @results;
      Walleye::Util::get_processes_by_con_id(\@results,param('con_id'),param('sensor'));
      param('process_id',$results[0][0]);
  }

  $table->addRow(Walleye::Process::get_ps());
  $q->param('act','treef');
  $table->addRow("Process_Tree");
  $table->addRow("<iframe  width=\"100%\" height=\"400\" src=\"".$q->url(-query=>1)."\"></iframe>");
  $q->param('act','ctf');
  $q->param('process_tree',param('process_id'));
  $q->delete("process_id");
  $table->addRow("Related Network Connections\n");
  $table->addRow("<iframe  width=\"100%\" height=\"250\" src=\"".$q->url(-query=>1)."\"></iframe>");

  $table->setCellClass(2,1,"sum_h");
  $table->setCellClass(3,1,"et_fun");
  $table->setCellClass(4,1,"sum_h");
  $table->setCellClass(5,1,"et_fun");

  return $table->getTable
}


sub get_frame{
    
    my $con_id     = param('con_id');
    my $process_id = param('process_id');
    my $sensor     = param('sensor');
    my @processes;

    my $html;

    my $start_proc;

    #---- its a bad idea to cache the graphs if one of
    #---- of the leafs is still "growing"
    
    #------ find matching processes
    my @results;

    if($con_id){
	Walleye::Util::get_processes_by_con_id(\@processes,$con_id,$sensor);
    }else{
	$processes[0][0] = $process_id;
    }
    $start_proc = $processes[0][0];

    push(@results,@processes);

   
    
    Walleye::Util::get_decendant_processes(\@processes,\@results,1,$sensor);
 
    push(@results,@processes);

    Walleye::Util::get_ancestor_processes(\@processes,\@results,1,$sensor);

    push(@results,@processes);


    my $fname = File::Temp::tempnam("images/","XXXXXXXX");
    my $dotfile         = "/var/www/html/walleye/".$fname.".dot";

       
    $fname .= ".png";

    my $pngfile = "/var/www/html/walleye/".$fname;

    my $buffer;

    #---- ok so this is pretty lame, when do the files get removed?
    $ENV{"PATH"} = ""; 
    #--- duplicate output to two named pipes
    open(DOT,"| /usr/bin/tee $dotfile |  $dotbin  -Tpng -o $pngfile  ");
    gen_dot_graph(\@results,"",$start_proc,$sensor);
    close(DOT);


    #--- gen the image map
    open(MAP,"$dotbin -Tcmapx $dotfile | ");
    while(<MAP>){
	$buffer .= $_;
    }
    #----we can erase the image map safely now, not needed anymore
    unlink($dotfile);
    
    $buffer .=  "<img border=\"0\" src=\"$fname\"  USEMAP=\"#proc_tree\">\n";

    #---- go through the directory and remove all files older than 1 minute
    opendir(DIR,"/var/www/html/walleye/images") or die" unable to open dir images/\n";
    while(defined($fname = readdir DIR)){
	if((stat("/var/www/html/walleye/images/$fname"))[8] < (time() - 60)){
            if($fname =~/^(\w+)(.png|.dot)$/){
              $fname= "/var/www/html/walleye/images/" . $1.$2; 
		unlink($fname);
            }

	}
    }

    #----- render this pig
    my $table = new HTML::Table(
				-class=>"et",
				-padding=>1,
				-border=>1,
				);

    $table->addRow($buffer);
		 
    $table->setColClass(1,"sum_body");

    return $table->getTable;
}
