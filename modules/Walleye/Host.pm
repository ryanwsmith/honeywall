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
#----- Host View
#-----
#----- Version:  $Id: Host.pm 1763 2005-07-15 17:25:12Z cvs $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  
#-----

package Walleye::Host;
use strict;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;

use CGI qw/:standard/;
use Socket;

use Walleye::Util;



#----- Module stuff

require Exporter;
our @ISA=("Exporter");
#our @EXPORT = qw (get_hd);
	    
#-----

#---- these pups used by the gen_hd ------
use Net::Whois::IP qw(whoisip_query);

#------ gen_hd: generate host details
sub get_hd{
    my $ip    = inet_ntoa(pack('N',param('ip')));
    my $target = param('ip');
    my $hostname;

    my $table = new HTML::Table(
				-class=>'body',
				);

    #------ get WHOIS info for the host
    my $whois_table = new HTML::Table(
				-class=>'summary',
				);

    $whois_table->addRow("Whois Information");
    $whois_table->setCellColSpan(1,1,2);

    my $results;
    my $key;
    my $line;

    eval{
      $results  = whoisip_query($ip);
      foreach $key(keys %$results){
        $line = $$results{$key};
        $whois_table->addRow($key,$line);
      }

    };

    if($@){
	#--- whois tried to croak
	$whois_table->addRow("Error","$@");
    }

    $whois_table->setColClass(1,"sum_head_l");
    $whois_table->setColClass(2,"sum_body");
    $whois_table->setCellClass(1,1,"sum_h");


  
    my $string;

    my $rr;
    my $rr2;
    
    my $other_table = new HTML::Table(
				-class=>'summary',
				);
    $other_table->addRow("Host Information ");
    $other_table->setCellColSpan(1,1,2);
    #----- DNS Info
    

    $hostname = gethostbyaddr(pack('N',$target),AF_INET);
   
   
    $other_table->addRow("IP Address:",$ip);
    $other_table->addRow("Current Hostname:",$hostname);

    #----- get os history
    my $query = "select MIN(start_sec), os.genre, os.detail  from argus, os ";
    $query .= " where argus.client_os_id = os.os_id ";
    $query .= " and ! ISNULL(argus.client_os_id) and (src_ip = ? ) group by os.os_id order by start_sec ";

    my $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute($target);

    my $ref = $sql->fetchall_arrayref();

    my $fp_table = new HTML::Table;

    $fp_table->addRow("First Observed","Operation System");

     
    foreach $line(@$ref){
        #--- hackorama
	$$line[1] =~ s/\0+//g;
	$$line[2] =~ s/\0+//g;
	
	$fp_table->addRow(scalar gmtime($$line[0]),$$line[1],$$line[2]);
    }

    $fp_table->setCellColSpan(1,2,2);
    $fp_table->setColClass(1,"sum_body");
    $fp_table->setColClass(2,"sum_body");
    $fp_table->setColClass(3,"sum_body");
    $fp_table->setCellClass(1,1,"sum_head_t");
    $fp_table->setCellClass(1,2,"sum_head_t");

    $other_table->addRow("OS Fingerprint<br>History:",$fp_table->getTable);


    my %lut;
    #----- get localality of host.
    $query  = "select sensor.sensor_id, sensor.name, argus.local, count(argus.argus_id), count(sys_socket.sys_socket_id), count(ids.ids_id) from argus ";
    $query .= " left join sensor on sensor.sensor_id = argus.sensor_id ";
    $query .= " left join sys_socket on argus.sensor_id = sys_socket.sensor_id and argus.argus_id = sys_socket.argus_id ";
    $query .= " left join ids on argus.sensor_id = ids.sensor_id and argus.argus_id = ids.argus_id ";
    $query .= " where src_ip = ?  group by argus.sensor_id, argus.local order by argus.local";
    $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute($target);
    $ref = $sql->fetchall_arrayref();

    my $sebeked =  "";
    my $sen_loc   =  "";

    foreach $line(@$ref){
	if($$line[4] > 0){
	    $sebeked = "<img src=\"button.gif\"\>";
	}else{
	    $sebeked = "";
	}

	if($$line[2] > 0){
	    $sen_loc = "<img src=\"button.gif\"\>";
	}else{
	    $sen_loc = "";
	}

	$lut{$$line[1]}{"id"}       = $$line[0];
	$lut{$$line[1]}{"outbound"} = $$line[3];
	$lut{$$line[1]}{"out_ids"}  = $$line[5];
	$lut{$$line[1]}{"sebeked"}  = $sebeked;
	$lut{$$line[1]}{"local"}    = $sen_loc;
    }


    $query  = "select sensor.name, count(argus.argus_id), count(ids.ids_id)  from argus  ";
    $query .= " left join sensor on sensor.sensor_id = argus.sensor_id ";
    $query .= " left join ids on argus.sensor_id = ids.sensor_id and argus.argus_id = ids.argus_id ";
    $query .= " where dst_ip = ?  group by argus.sensor_id";
    $sql = $Walleye::Util::dbh->prepare($query);
    $sql->execute($target);
    $ref = $sql->fetchall_arrayref();


    foreach $line(@$ref){
	$lut{$$line[0]}{"inbound"} = $$line[1];
	$lut{$$line[0]}{"in_ids"}  = $$line[2];
    }
    



    my $locality_table = new HTML::Table;
    my $seen=0;
    $locality_table->addRow("Sensor","Local","Sebeked","Initiated<br>Connections","Initiated<br>IDS","Recieved<br>Connections","Recieved<br>IDS");
    

    $sebeked =  "";
    $sen_loc   =  "";
    my $sensor;

    param("act","ct");
   
    foreach $sensor(sort keys %lut){
	param("sensor",$lut{$sensor}{"id"});
       	$locality_table->addRow(
				"<a  href=\"".url(-query=>1)."\">".$sensor."</a>",
				$lut{$sensor}{"local"},
				$lut{$sensor}{"sebeked"},
				$lut{$sensor}{"outbound"},
				$lut{$sensor}{"out_ids"},
				$lut{$sensor}{"inbound"},
				$lut{$sensor}{"in_ids"},
				)

    }
    $locality_table->setColClass(1,"sum_body");
    $locality_table->setColClass(2,"sum_body");
    $locality_table->setColClass(3,"sum_body");
    $locality_table->setColClass(4,"sum_body");
    $locality_table->setColClass(5,"sum_body");
    $locality_table->setColClass(6,"sum_body");
    $locality_table->setColClass(7,"sum_body");
    $locality_table->setCellClass(1,1,"sum_head_t");
    $locality_table->setCellClass(1,2,"sum_head_t");
    $locality_table->setCellClass(1,3,"sum_head_t");
    $locality_table->setCellClass(1,4,"sum_head_t");
    $locality_table->setCellClass(1,5,"sum_head_t");
    $locality_table->setCellClass(1,6,"sum_head_t");
    $locality_table->setCellClass(1,7,"sum_head_t");
       
    $other_table->addRow("Observed By:",$locality_table->getTable);
    

    $other_table->setColClass(1,"sum_head_l");
    $other_table->setColClass(2,"sum_body");
    $other_table->setCellClass(1,1,"sum_h");	

    $table->addRow($other_table->getTable,$whois_table->getTable);
    #$table->addRow($whois_table->getTable);
		  
    return $table->getTable;

}

