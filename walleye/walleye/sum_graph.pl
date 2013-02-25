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

#
#----- sum_graph.pl:  Walleye component for creating graphical event summaries
#-----
#----- Version:  $Id: sum_graph.pl 5034 2007-01-26 20:26:27Z cviecco $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  
#-----           Camilo Viecco <cviecco@indiana.edu>
#-----

use strict;
use 5.004;

use CGI qw/:standard/;

use GD::Graph::lines;
use GD::Graph::area;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;
use Socket;

use Walleye::Util;



sub main{
    #----- variables via CGI ----------------------------
    my $sensor      = param('sensor');
    my $daysback    = param('days');
    #----------------------------------------------------
   
    Walleye::Util::setup(1,0,0);

    
    if(!$sensor){
	$sensor          = 0;
    }

    if(!$daysback){
	$daysback = 1;
    }

    print "Content-type: image/png\n\n";

    my $now = time() ;

    my $start = $now - ($daysback * 86400);
   

    my $query = "select src_start_sec , SUM(src_bytes + dst_bytes), COUNT(DISTINCT(ids.ids_id))";
    $query .= " from flow left join ids on ids.flow_id = flow.flow_id and ids.sensor_id = flow.sensor_id ";
    $query .= " where flow.sensor_id = ? ";
    $query .= " and src_start_sec > ? ";
    $query .= " and src_bytes > 0 and dst_bytes > 0 ";
    $query .= " group by DATE_FORMAT(FROM_UNIXTIME(src_start_sec),\"%D %H \") ";

  
    my $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute($sensor,$start);
  
    my $ref = $sql->fetchall_arrayref();

 


    my @data;
    my $x;

    my $maxy;
    my @time;


  
    my $y = 0;
    my %lut;
   

    for($x=$start;$x<=$now;$x+=3600){
	
	@time = gmtime($x);
	$data[0][$y] = $time[2].":00";
	$data[1][$y] = 0;
	$data[2][$y] = 0;
	$lut{$time[3]." ".$time[2]} = $y;
	
	$y++;
    }

    

    foreach (@$ref){
	@time = gmtime($$_[0]);
	$x = $lut{$time[3]." ".$time[2]};
	$data[1][$x] = ($$_[1] /1000);
	$data[2][$x] = $$_[2] * 10;
	$x++;
    }

    

    my $my_graph = GD::Graph::area->new(240, 80);
    $my_graph->set_legend( 
			   "KBytes Transfered",
			   "N/10 Alerts"
			   );
    $my_graph->set(
		   transparent       => 1,
		   long_ticks        => 1,
		   #two_axes          => 1,
		   bgclr             => 'black',
		   fgclr             => 'gray',
		   dclrs             => ['lorange','lred'],
		   boxclr            => 'white',
		   #x_label           => 'y begs to be logarithmic',
		   #y1_label          => 'kbytes',
		   #y2_label          => 'Alerts',
		   title             => "",
		   y_min_value       => 0,
		   #y1_max_value       => 5000,
		   #y2_min_value      => 0,
		   y_max_value       => 2000,
		   #y_max_value       =>1000,    
		   y_tick_number     => 4,
		   y_label_skip      => 2,
		   x_label_skip      => 8,
		   ) or die $my_graph->error;
    
    print $my_graph->plot(\@data)->png or die $my_graph->error;

}

main();
