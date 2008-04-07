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

#----- Walleye:  Honeywall Data Analysis Interface Utilities
#-----
#----- Version:  $Id: Util.pm 5044 2007-01-30 16:52:21Z cviecco $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  
#-----

package Walleye::Util;
use strict;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;


use Walleye::Login;

#----- Module stuff

require Exporter;
our @ISA=("Exporter");
#our @EXPORT = qw ($dbh %proto_lut %port_lut 
#	      load_protos 
#	      load_ports 
#	      hash_to_in 
#	      array_to_in
#	      get_processes_by_con_id
#	      get_ancestor_processes
#	      get_decendant_processes
#	      get_time_range
#	      get_sockets
#	      get_decendant_sockets
#	      get_ancestor_sockets
#	      select_flow_table
#	      scrub_cgi
#	      result_pager
#	      setup);

our $dbh;
our %proto_lut;
our %port_lut;

#-----

my $db          = "hflow";

my $dbpasswd    = "honey";
my $dbuid       = "walleye";
my $dbserver    = "";
my $dbport      = "";

my $proto_file  = "/etc/protocols";
my $port_file   = "/etc/services";

my $pager_span  = 7;


sub load_protos{
    #----- we should load this into the database
    my $line;
    my $proto;
    my $num;
    my $txt;
    my $comment;
    
    open(PROTO,$proto_file) || die "unable to open $proto_file\n";

    foreach (<PROTO>){
	next if(/^\#/);
	
	($proto,$num,$txt,$comment) = split(/\s+/,$_);

	if($num && $txt){
	    #print "matching $num -> $txt\n";
	    $proto_lut{$num} = $txt;
	}
    }

}



#------ ports need to be loaded after we load protos.

sub load_ports{
    #------ we should load this into the db.
    my $line;
    my $srv;
    my $pp;
    my $alias;
    my $port;
    my $proto;
    
    open(PORT,$port_file) || die "unable to open $port_file\n";

    foreach (<PORT>){
	next if(/^\#/);
	next if(/^\s+/);
	
	($srv,$pp,$alias) = split(/\s+/,$_);
	($port,$proto)    = split(/\//,$pp);

	if($port && $proto && $srv){
	    #print "$proto - $port == $srv\n";
	    $port_lut{uc($proto)}{$port} = $srv;
	}

    }

}


sub hash_to_in{
    my $array_ref = shift;

    my $output = " ( ";
    my $row;
    
    my $first = 1;

    foreach $row (keys %$array_ref){
        if($first){
            $first = 0;
        }else{
            $output .= " , ";
        }
        $output .= " '$row' ";
    }

    $output .= " )";

    return $output;
}


sub array_to_in{
    my $array_ref = shift;
    my $pos       = shift;

    my $output = " ( ";
    my $row;
    my $entry;
    my $first = 1;

    foreach $row (@$array_ref){
        if($first){
            $first = 0;
        }else{
            $output .= " , ";
        }
        $entry = $$row[$pos];
        $output .= " '$entry' ";
    }

    $output .= " )";

    return $output;
}

sub get_processes_by_con_id{
    my $res_ref   = shift;
    my $con_id    = shift;
    my $sensor    = shift;

    if(!defined $con_id){
	return;
    }
    

    my $query  = "select sys_socket.process_id from sys_socket, flow ";
       $query .= " where flow.sensor_id = sys_socket.sensor_id and flow.sensor_id = ? and ";
       $query .= " flow.flow_id = sys_socket.flow_id and flow.flow_id = ? ";

    my $sql = $dbh->prepare($query);
    $sql->execute($sensor,$con_id) or die;


    my $process_id_col = $sql->fetchall_arrayref(); 

    if($$process_id_col[0]){
	#warn("we found a mapping for con_id $con_id\n");
	push(@{$res_ref},@{$process_id_col});
    }

}




sub get_ancestor_processes{
    my $res_ref = shift;       #--- result array reference
    my $t_ref   = shift;       #--- target process_id reference, this is NOT a OS PID it is a process reference id
    my $recurse = shift;       #--- is true then we recursive find all ancestors, 
                               #--- otherwise we get only immediate ancestors
    my $sensor  = shift;

    if(@$t_ref == 0){
	return;
    } 

    my $target  = array_to_in($t_ref,0);
    my $query = "select parent_process from process_tree where child_process in $target and  sensor_id = ?";
    
    my $sql = $dbh->prepare($query);

    #warn $query;

    $sql->execute($sensor);

    my $process_id_col = $sql->fetchall_arrayref();
    
    if($$process_id_col[0]){
	#print" hey we found ancestors for $sensor: $target <br>\n";
	push(@{$res_ref},@{$process_id_col});
  
	if($recurse){
	    get_ancestor_processes($res_ref,$process_id_col,$recurse,$sensor);
	}   
    }
}

sub get_decendant_processes{
    my $res_ref = shift;
    my $t_ref   = shift;
    my $recurse = shift;
    my $sensor  = shift;

  
    if(@$t_ref == 0){
	return;
    }

    my $target  = array_to_in($t_ref,0);

    my $query = "select child_process from process_tree where parent_process in $target and sensor_id = ?  ";
    
    my $sql = $dbh->prepare($query);

    $sql->execute($sensor);

    my $process_id_col = $sql->fetchall_arrayref;
   
    if($$process_id_col[0]){

	push(@{$res_ref},@{$process_id_col});
 
	if($recurse){
	    get_decendant_processes($res_ref,$process_id_col,$recurse,$sensor);
	}   
    }
}



sub get_time_range{
    my $t_ref   = shift;
    my $sensor  = shift;

    if(@$t_ref == 0){
	return;
    }

    my $target  = array_to_in($t_ref,0);        
    my $query = "select MIN(time_min) , MAX(time_max) from process where process_id in $target and sensor_id = ?";
    my $sql = $dbh->prepare($query);
    $sql->execute($sensor);

    return  $sql->fetchrow_arrayref;

    

}
sub get_sockets{
    my $res_ref = shift;
    my $t_ref   = shift;
    my $sensor  = shift;

    
    my $target  = array_to_in($t_ref,0);

    my $query = "select sys_socket_id from sys_socket where process_id in $target and sensor_id = ?";
    
    my $sql = $dbh->prepare($query);

    $sql->execute($sensor);

    my $sock_id_col    = $sql->fetchall_arrayref([0]);

    if($$sock_id_col[0]){
	push(@{$res_ref},@{$sock_id_col});
    }
   

}

sub get_decendant_sockets{
    my $res_ref = shift;
    my $t_ref   = shift;

    my $recurse = shift;
    my $sensor  = shift;

    my @results;
    
    get_decendant_processes(\@results,$t_ref,$recurse,$sensor);
    
    if(@results == 0){
	return;
    }

    get_sockets($res_ref,\@results,$sensor);
}


sub get_ancestor_sockets{
    my $res_ref = shift;
    my $t_ref   = shift;
    my $recurse = shift;
    my $sensor  = shift;

    my @results;
    
    get_ancestor_processes(\@results,$t_ref,$recurse,$sensor);

    if(@results == 0){
	return;
    }

    get_sockets($res_ref,\@results,$sensor);
}

#--camilo's test
sub expand_array_params{
   my $array_ref =shift;
   #my $bindings  =shift;

    my $output = " ( ";
    my $a_size = scalar @$array_ref;
    my $i;
   
    for($i=0;$i<$a_size-1;$i++){
        $output .= " ? ,";
        #push(@$bindings,@$array_ref[$i]);
        
    }
    #and add the last
    $output .= "? )";
    #push(@$bindings,@$array_ref[$i]);
   #warn ("is this correct? = $output");
   return $output;     

}


#--- takes as input the reference to the CGI query object
#--- a references to the bindings array 
#---
#--- returns a query substring and populates the bindinds 
#--- into the array.
sub gen_flow_query_filter{
    my $q        = shift;    #--- CGI query reference
    my $bindings = shift;    #--- bindings array reference
    my $and      = shift;
    my $notime   = shift;    

    
    my $query;
    my $i;
    my @local_array;
    

    if(!$notime){
      #--- start time
      if($q->param('st')){
  	if($$and++){
	    $query .= " and ";
	}
	$query .= " GREATEST(src_end_sec,dst_end_sec) >= ? ";
	push(@$bindings,$q->param('st'));
      }

      #--- end time
      if($q->param('et')){
	if($$and++){
	    $query .= " and ";
	}
	$query .= " src_start_sec <= ? ";
	push(@$bindings,$q->param('et'));
      }
    }
    #--- only consider bidirectional network flows
    if($q->param('bidi')){
	if($$and++){
	    $query .= " and ";
	}
	$query .= "  src_bytes > 0 and dst_bytes > 0 ";
    }

    
     #--- only consider flows that exceed bytes_transfered value
    if($q->param('transfered_bytes')){
	if($$and++){
	    $query .= " and ";
	}
	$query .= "  src_bytes + dst_bytes >= ? ";
	push(@$bindings,$q->param('transfered_bytes'));
    }

    #--- only consider flows with associated ids events
    if($q->param('ids')){
	if($$and++){
	    $query .= " and ";
	}
	$query .= " flow.flow_id = ids.flow_id ";
    }
    
    
    #--- filter based on IP endpoint info
    if($q->param('ip')){
	if($q->param('mask')){
	    if($$and++){
		$query .= " and ";
	    }
	    $query .= "  (flow.src_ip >> 32 - ?  = ?  or flow.dst_ip >> 32 - ?  = ?) ";
	    push(@$bindings,$q->param('mask'));
	    push(@$bindings,$q->param('ip') >> 32 - $q->param('mask') );
	    push(@$bindings,$q->param('mask'));
	    push(@$bindings,$q->param('ip') >> 32 - $q->param('mask') );

	}else{

	    if($$and++){
		$query .= " and ";
	    }
	    #$query .= "  (flow.src_ip = ?  or flow.dst_ip = ?) ";
	    #push(@$bindings,$q->param('ip'));
	    #push(@$bindings,$q->param('ip'));
            @local_array=$q->param('ip');
            $query .= "( flow.src_ip in ".expand_array_params(\@local_array);
            push(@$bindings,$q->param('ip'));
            $query .= "or flow.dst_ip in ".expand_array_params(\@local_array).")";
            push(@$bindings,$q->param('ip'));


	}
    }else{

	if($q->param('src_ip')){
	    if($q->param('src_mask')){
		if($$and++){
		    $query .= " and ";
		}
		$query .= "  (flow.src_ip >> 32 - ?  = ?   ";
		push(@$bindings,$q->param('src_mask'));
		push(@$bindings,$q->param('src_ip') >> 32 - $q->param('src_mask') ); 
	    
	    }else{
		if($$and++){
		    $query .= " and ";
		}
		#$query .= "  flow.src_ip = ? ";
		#push(@$bindings,$q->param('src_ip'));
                @local_array=$q->param('src_ip');
                $query .="flow.src_ip in ".expand_array_params(\@local_array);
                push(@$bindings,$q->param('src_ip'));

	
	    }

	}

	
	if($q->param('dst_ip')){
	    if($q->param('dst_mask')){
		if($$and++){
		    $query .= " and ";
		}
		$query .= "  (flow.dst_ip >> 32 - ?  = ?   ";
		push(@$bindings,$q->param('dst_mask'));
		push(@$bindings,$q->param('dst_ip') >> 32 - $q->param('dst_mask') ); 
	    }else{
		if($$and++){
		    $query .= " and ";
		}
		#$query .= "  flow.dst_ip = ? ";
		#push(@$bindings,$q->param('dst_ip'));

                $query .= "flow.dst_ip in ";
                @local_array=$q->param('dst_ip');
                $query .=expand_array_params(\@local_array);
                push(@$bindings,$q->param('dst_ip'));

	
	    }
	}
    }
    #----- inverted ip filters (not ip form)
    if($q->param('no_src_ip')){
        if($$and++){
           $query .= " and ";
        }
        @local_array=$q->param('no_src_ip');
        $query .="flow.src_ip not in ".expand_array_params(\@local_array);
        push(@$bindings,$q->param('no_src_ip'));
    }

    if($q->param('no_dst_ip')){
        if($$and++){
           $query .= " and ";
        }
        @local_array=$q->param('no_dst_ip');
        $query .="flow.dst_ip not in ".expand_array_params(\@local_array);
        push(@$bindings,$q->param('no_dst_ip'));
    }

    if($q->param('no_dst_port')){
        if($$and++){
           $query .= " and ";
        }
        @local_array=$q->param('no_dst_port');
        $query .="flow.dst_port not in ".expand_array_params(\@local_array);
        push(@$bindings,$q->param('no_dst_port'));
    }
    if($q->param('no_src_port')){
        if($$and++){
           $query .= " and ";
        }
        @local_array=$q->param('no_src_port');
        $query .="flow.src_port not in ".expand_array_params(\@local_array);
        push(@$bindings,$q->param('no_src_port'));
    }




    #----- port filters
    if($q->param('port')){
        my $a_cam_size;
        my @local_a;
        #--@local_a=$q->param('port');
        #--$a_cam_size=scalar {($q->param('port'))};
        #--$a_cam_size= @local_a;
        #--print "a_size=$a_cam_size <p>";
	if($$and++){
	    $query .= " and ";
	}
	#$query .= "  ( flow.src_port = ? or flow.dst_port = ?) ";
	#push(@$bindings,$q->param('port'));	
	#push(@$bindings,$q->param('port'));
        @local_array=$q->param('port');
        $query .= "( flow.src_port in ".expand_array_params(\@local_array);
        push(@$bindings,$q->param('port'));
        $query .= "or flow.dst_port in ".expand_array_params(\@local_array).")";
        push(@$bindings,$q->param('port'));





        #---------------
        
    }else{

	if($q->param('src_port')){
	    if($$and++){
		$query .= " and ";
	    }
	    #$query .= "  flow.src_port = ? ";
	    #push(@$bindings,$q->param('src_port'));
            @local_array=$q->param('src_port');
            $query .="flow.src_port in ".expand_array_params(\@local_array);
            push(@$bindings,$q->param('src_port'));
	
	}
	if($q->param('dst_port')){
	    if($$and++){
		$query .= " and ";
	    }
	    #$query .= "  flow.dst_port = ? ";
	    #push(@$bindings,$q->param('dst_port'));
            @local_array=$q->param('dst_port');
            $query .="flow.dst_port in ".expand_array_params(\@local_array);
            push(@$bindings,$q->param('dst_port'));	
	}
    }

    #--- filter based on the sensor ID
    if(defined $q->param('sensor')){
	if($$and++){
	    $query .= " and ";
	}
	#$query .= "  flow.sensor_id = ? ";
	#push(@$bindings,$q->param('sensor'));
        $query .= "flow.sensor_id in ";
        @local_array=$q->param('sensor');	
        $query .=expand_array_params(\@local_array);
        push(@$bindings,$q->param('sensor'));
        	
    }
    
    #--- look for flows who's source is local to the honeynet
    if(defined $q->param('src_local')){
        #cviecco
	#if($$and++){
	#    $query .= " and ";
	#}
	#$query .= "  argus.local = ? ";
	#push(@$bindings,$q->param('src_local'));	
	
    }
    
    #--- get a specific flow
    if(defined $q->param('con_id')){
	    if($$and++){
		$query .= " and ";
	    }
	    $query .= "  flow.flow_id = ? ";
	    push(@$bindings,$q->param('con_id'));	
	    
	}
    
    #--- filter on the ip protocol
    if(defined $q->param('ip_proto') ){
	if($$and++){
	    $query .= " and ";
	}
	$query .= "  flow.ip_proto = ? ";
	push(@$bindings,$q->param('ip_proto'));	
    }
    #---- filter multicast/broadcast
    if(defined $q->param('no_xcast') ){
        if($$and++){
            $query .= " and ";
        }
        $query .= "  ((flow.dst_ip & 0xE0000000 != 0xE0000000) and (flow.src_ip | 0xFF != flow.dst_ip)) ";
        #--push(@$bindings,$q->param('ip_proto'));
    }
    #---- filter min packets
    if(defined $q->param('min_flow_packets') ){
        if($$and++){
            $query .= " and ";
        }
        $query .= "  flow.src_packets+flow.dst_packets >= ? ";
        push(@$bindings,$q->param('min_flow_packets'));
    }

   #--- v .=  $q->hidden("min_flow_packets");

    
    return $query;
}


#--- aggregate_by
#---
#--- provides aggregate by visual element.
#--- hand done cause popup_menu used fuxored up
#---
sub aggregate_by{
    my $target = shift;
   
    my $q = new CGI;

    $q->param('page','1');

    my %labels = ('src_ip'=>'Source IP ',
		  'dst_ip'=>'Destination IP',
		  'src_port'=>'Source Port',
		  'dst_port'=>'Destination Port');
    
  
    my $agg_nav   = "<select name=\"aggby\" onChange=\"submit()\">";

    my $val;
    my $selected;

    foreach $val (keys %labels){
	if($target eq $val){
	    $selected = "selected=\"selected\"";
	}else{
	    $selected = "";
	}

        $agg_nav .= "<option ".$selected." value=\"".$val."\">".$labels{$val}."</option>";
    }

    $agg_nav .= "</select>";


    my $nav = $q->start_form(-method=>'get',-action=>$q->url());


    #--- list out all other possible values that need to be added and yet hidden
    $nav .=  $q->hidden("st");
    $nav .=  $q->hidden("et");
    $nav .=  $q->hidden("ip");
    $nav .=  $q->hidden("src_ip");
    $nav .=  $q->hidden("dst_ip");
    $nav .=  $q->hidden("mask");
    $nav .=  $q->hidden("src_mask");
    $nav .=  $q->hidden("dst_mask");
    $nav .=  $q->hidden("port");
    $nav .=  $q->hidden("src_port");
    $nav .=  $q->hidden("dst_port");
    $nav .=  $q->hidden("transfered_bytes");
    $nav .=  $q->hidden("act");
    $nav .=  $q->hidden("src_local");
    $nav .=  $q->hidden("page");
    $nav .=  $q->hidden("sensor");
    $nav .=  $q->hidden("ids");
    $nav .=  $q->hidden("no_xcast");   
    $nav .=  $q->hidden("min_flow_packets");
    $nav .=  $q->hidden("ip_proto");
    $nav .=  $q->hidden("no_src_ip");
    $nav .=  $q->hidden("no_dst_ip");
    $nav .=  $q->hidden("no_src_port");
    $nav .=  $q->hidden("no_dst_port");
 
    $nav .= $agg_nav;

    $nav .= $q->end_form;

    return $nav;


}


#--- select_flow_table
#---
#--- provides a html table for the setting of flow filtering and grouping 
#--- criteria. used by aggregate_flow and connection table views.
#--- 
#--- the first and only parameter is a binary flag, if set 
#--- the grouping option will be displayed.
#---
sub select_flow_table{

    my $aggregate = shift;  


    my $q= new CGI;

    my %labels = ('6'=>'TCP Flows',
		 '17'=>'UDP Flows',
		 '1'=>'ICMP Flows',
		 'undef'=>'Any Proto');

    
    if(! defined $q->param('ip_proto')){
	$q->param('ip_proto',"undef")
    }

    $q->param('page','1'); ##cviecco changed from 2 to 1

    my $proto_nav = $q->popup_menu('ip_proto',
				   ['6','17','1','undef'],
				   $q->param('ip_proto'),\%labels);
    
    
    my $time_nav = $q->checkbox(-name=>'all_times',
				-checked=>0,
				-value=>'1',
				-label=>'All Time Periods');

    my $related_nav = $q->checkbox(-name=>'sebek_tracked',
				-checked=>0,
				-value=>'1',
				 -label=>'Sebek Related Flows Only');

    my $bidi_nav = $q->checkbox(-name=>'bidi',
				-checked=>0,
				-value=>'1',
				 -label=>'Bidirectional Flows Only ');

    my $xcast_nav = $q->checkbox(-name=>'no_xcast',
                                -checked=>0,
                                -value=>'1',
                                 -label=>'Exclude non unicast Flows ');



    %labels = ('0'     =>'Inbound',
	       '1'     =>'Outbound',
	       'undef' =>'Either' );

    my $src_local_nav     = $q->radio_group(-name=>'src_local',
                                        -values=>['0','1','undef'],
                                        -default=>'undef',
                                        -linebreak=>'true',
				        -labels=>\%labels);



    %labels = ('ct'=>'Detailed ',
	       'aggt'=>'Aggregate ');
    my $view_nav     = $q->radio_group(-name=>'act',
                                        -values=>['aggt','ct'],
+                                        -default=>'aggt',
                                        -linebreak=>'true',
				        -labels=>\%labels);

   
    my $nav = $q->start_form(-method=>'get',-action=>$q->url());


    #--- list out all other possible values that need to be added and yet hidden
    $nav .=  $q->hidden("st");
    $nav .=  $q->hidden("et");
    $nav .=  $q->hidden("ip");
    $nav .=  $q->hidden("src_ip");
    $nav .=  $q->hidden("dst_ip");
    $nav .=  $q->hidden("mask");
    $nav .=  $q->hidden("src_mask");
    $nav .=  $q->hidden("dst_mask");
    $nav .=  $q->hidden("port");
    $nav .=  $q->hidden("src_port");
    $nav .=  $q->hidden("dst_port");
    $nav .=  $q->hidden("transfered_bytes");
    $nav .=  $q->hidden("aggby");
    $nav .=  $q->hidden("sensor"); ##cviecco
    #--$nav .=  $q->hidden("no_xcast"); ## no need to add here as it is an option
    $nav .=  $q->hidden("min_flow_packets");
    #--- THIS WORK?
    $nav .=  $q->hidden("page");
    #$nav .=  $q->hidden("act");
    $nav .=  $q->hidden("no_src_ip");
    $nav .=  $q->hidden("no_dst_ip");
    $nav .=  $q->hidden("no_src_port");
    $nav .=  $q->hidden("no_dst_port");

  
    my $nav_table    = new HTML::Table(-border=>0,-spacing=>0,-padding=>0);	
    my $filter_table = new HTML::Table(-border=>0,-spacing=>0,-padding=>0);

    $filter_table->addRow($proto_nav);
    $filter_table->addRow($bidi_nav);
    $filter_table->addRow($xcast_nav);
   
    $filter_table->addRow($related_nav);
    #$filter_table->addRow($time_nav);
    
    $nav_table->addRow("<fieldset><legend>View</legend>".$view_nav."</fieldset>");
    $nav_table->addRow("<fieldset><legend>Flow Direction Filter</legend>".$src_local_nav."</fieldset>");
    $nav_table->addRow("<fieldset><legend>Other Filters</legend>".$filter_table->getTable."</fieldset>");
    $nav_table->addRow($q->submit);
   
    $nav .= $nav_table->getTable;

    $nav .= $q->end_form;

    return $nav;
}

sub init_chkbox_filter{
    my $target =shift;
    my $q= new CGI;
    $q->param('page','1');

    my $nav = $q->start_form(-method=>'get',-action=>$q->url());
    $nav .=  $q->hidden("act");
    #$nav .=  $q->submit( -name=>'Reset Filters');
    #$nav .=  $q->end_form;

    #--- list out all other possible values that need to be added and yet hidden
    $nav .=  $q->hidden("st");
    $nav .=  $q->hidden("et");
    $nav .=  $q->hidden("ip");
    $nav .=  $q->hidden("mask");
    $nav .=  $q->hidden("src_mask");
    $nav .=  $q->hidden("dst_mask");
    $nav .=  $q->hidden("port");

    $nav .=  $q->hidden("transfered_bytes");
    $nav .=  $q->hidden("aggby");
    $nav .=  $q->hidden("sensor"); ##cviecco
    #--$nav .=  $q->hidden("no_xcast"); ## no need to add here as it is an option
    $nav .=  $q->hidden("min_flow_packets");



    if ($target ne "src_ip"){
       $nav .=  $q->hidden("src_ip");
       $nav .=  $q->hidden("no_src_ip");
    }
    if ($target ne "dst_ip"){
       $nav .=  $q->hidden("dst_ip");
       $nav .=  $q->hidden("no_dst_ip");
    }
    if ($target ne "src_port"){
       $nav .=  $q->hidden("src_port");
       $nav .=  $q->hidden("no_src_port");
    }
    if ($target ne "dst_port"){
       $nav .=  $q->hidden("dst_port");
       $nav .=  $q->hidden("no_dst_port");
    }
    return $nav;
}

sub term_chkbox_filter{

    my $q= new CGI;
    $q->param('page','1');
    my $nav2;

    my $nav = $q->start_form(-method=>'get',-action=>$q->url());
   
    $nav2  =$q->submit( -name=>'Apply checkbox filters');
    $nav2 .=  $q->end_form;
    return $nav2;

}

#makes a form where the only survivors are the page, the sensor id, end time and starttime
sub clear_filter{
    my $q= new CGI;
    $q->param('page','1');

    my $nav = $q->start_form(-method=>'get',-action=>$q->url());
    $nav .=  $q->hidden("st");
    $nav .=  $q->hidden("et");
    $nav .=  $q->hidden("sensor");
    $nav .=  $q->hidden("act");
    $nav .=  $q->submit( -name=>'Reset Filters');
    $nav .=  $q->end_form;
    return $nav; 
}




sub setup{
    my $load_db     = shift;
    my $load_proto  = shift;
    my $load_port   = shift;


    if($load_db){
	$dbh = DBI->connect("DBI:mysql:database=$db;host=$dbserver;port=$dbport",$dbuid,$dbpasswd);

	if(!$dbh){
	  Walleye::Login::display_error_page("Unable to Connect to database: $db");
	}
    }

    if($load_proto){
	load_protos();
    }

    if($load_port){
	load_ports();
    }
    

}

#--- this simply removes parameters that are set to undef
sub scrub_cgi{
    my $q = shift;
    my  @names = $$q->param;

    foreach (@names){
	if($$q->param($_) eq "undef"){
	    $$q->delete($_);
	  }
    }
    
}


sub result_pager{
    my $current_page = shift;
    my $total_pages  = shift;
    my $param_string  = shift;

    if(!$param_string){
	$param_string = "page";
    }

    my $str;
    my $start;
    

    if($current_page < 1){
	$current_page = 1;
    }

    if($current_page > $total_pages){
	$current_page = $total_pages;
    }


    if($current_page - $pager_span < 0){
	$start = 1;
    }else{
	$start = $current_page - $pager_span;
    } 
    
    my $end = $start + (2 * $pager_span);
   
    if($end > $total_pages){
	$end  = $total_pages;
    }

    my $q = new CGI;
   

    scrub_cgi(\$q);

   


  

    my $table = new HTML::Table(
				-spacing=>0,
				-padding=>0,
				-border=>0
				);
    my @cells;

    if($current_page > 1){
         $q->param($param_string,$current_page - 1);
	 push(@cells, "<a href=\"".$q->url(-query=>1)."\">(Previous Page)</a>");
         $q->param($param_string,1);
         push(@cells, "<a href=\"".$q->url(-query=>1)."\">Start</a>");

    }else{
        push(@cells,"(Previous Page)");
	push(@cells,"Start");
    }

    my $x;
    my $y = $start;
    for($x = 0;$x < $pager_span * 2;$x++){

	$q->param($param_string,$y);
	if($y <= $total_pages){
	    if($y == $current_page){
	
		push(@cells,"$y");
	    }else{
		push(@cells, "<a href=\"".$q->url(-query=>1)."\">". $y  ."</a>");
	    }
	}else{
	    push(@cells,"-");
	}
	$y++;
    }

    
    if($current_page < $total_pages){
        $q->param($param_string,$total_pages);
	push(@cells, "<a href=\"".$q->url(-query=>1)."\">End</a>");	

	$q->param($param_string,$current_page +1);
	push(@cells, "<a href=\"".$q->url(-query=>1)."\">(Next Page)</a>");
    }else{
	push(@cells,"End");
	push(@cells,"(Next Page)");
    }

    push(@cells,"$current_page / $total_pages");

    $table->addRow(@cells);
    
    $table->setCellClass(1,1,"pager_ctl");
    $table->setCellClass(1,2,"pager_ctl");
 
    for($x = 3;$x <= ($pager_span*2)+2;$x++){
	$table->setCellClass(1,$x,"pager");
    }

    $table->setCellClass(1,2+($pager_span*2)+1,"pager_ctl");
    $table->setCellClass(1,2+($pager_span*2)+2,"pager_ctl");
    $table->setCellClass(1,2+($pager_span*2)+3,"pager_ctl");
 

    $table->setCellClass(1,$current_page - $start +3,"pager_cur");

    return $table->getTable;
    
}




1;
