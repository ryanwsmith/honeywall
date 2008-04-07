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
#----- Admin View
#-----
#----- Version:  $Id: Admin.pm 1763 2005-07-15 17:25:12Z cvs $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  

package Walleye::Admin;
use strict;
use DBI;
use DBI qw(:sql_types);
use DBD::mysql;

use HTML::Table;
use CGI qw/:standard/;
use Socket;

use Walleye::Util;

my $pcap_dir = "/var/log/pcap/";

#----- Module stuff

require Exporter;
our @ISA=("Exporter");
#our @EXPORT = qw (get_table);
	    
#-----

sub get_pcap_counts{
    
    my $results = shift;

    $ENV{"PATH"} = "";    
    open(PCAP,"cd $pcap_dir; /usr/bin/du -h | ");  

    my $size;
    my $dir;
    my $id;
    
    foreach (<PCAP>){
	($size,$dir) = split(' ');

	$dir =~ s/\D+//g;

	my $id = $dir;

	if($dir eq ""){
	    $dir = "Total";
	}else{
	    $dir = scalar(gmtime($dir));
	}
	
	$$results{$id}{"size"} = $size;
	$$results{$id}{"txt"}  = $dir;
	
    }

}

sub get_db_table_counts{
    my $query;
    my $sql;
    my $ref;
    my $ref2;
    my $x;
    my $results = shift;
    


    #--- get list of tables
    $query = "show tables";
    $sql   = $Walleye::Util::dbh->prepare($query);
    $sql->execute();
    $ref = $sql->fetchall_arrayref;

    
    #--- get row count for each table
    foreach (@$ref){
	$query = "select count(*) from $$_[0]";
	$sql   = $Walleye::Util::dbh->prepare($query);
	$sql->execute();
	$ref2 = $sql->fetchrow_arrayref;
	$$results{$$_[0]} = $$ref2[0];

	$x++;
    }
    
    return 1;
}

sub del_pcap_hour{
    my $target = shift;

    #untaint target
    if($target && $target =~ /^(\d+)$/){
	$target = $1;	
    }else{
	return;
    }

    my $name   = scalar(gmtime($target));
   
    $ENV{"PATH"} = ""; 
    if(!(-d "$pcap_dir$target" )){
	return "Unable to delete $name: $pcap_dir$target not found\n";
    }

    warn "deleting all pcap data for the hour of: $name\n";
    
    system("/etc/init.d/hflow-pcap stop");
    if(system("/bin/rm -rf $pcap_dir$target")){
	return "Delete $name: $pcap_dir$target failed\n";
    }
    system("/etc/init.d/hflow-pcap start");


    return "Delete $name: $pcap_dir$target removed\n";

}


sub gen_data_management{
    
    my $hflow      = new HTML::Table;
    my $pcap       = new HTML::Table;
    my $table      = new HTML::Table(-class=>'summary');


    my %db_tabs;
    my %pcap_tabs;

    my $q = new CGI;
    my $del_res;

    $ENV{"PATH"} = "";
    if($q->param('pcap_rm')){
	$del_res = del_pcap_hour($q->param('pcap_rm'));
    }

   
    #---- build hflow table
    $hflow->addRow("Hflow Database");
    $hflow->setCellColSpan(1,1,2);
    $hflow->addRow("DB Table","Count");
    $hflow->setCellClass(1,1,"sum_head_t");
    $hflow->setCellClass(2,1,"sum_head_t");
    $hflow->setCellClass(2,2,"sum_head_t");
    get_db_table_counts(\%db_tabs);
    my $key;
    foreach $key(sort keys %db_tabs){
	
	$hflow->addRow($key,$db_tabs{$key});
    }

    #--- build pcap table
    $pcap->addRow("PCAP Archive");
    $pcap->setCellColSpan(1,1,3);
    $pcap->addRow("Hour Of","Count","Delete");
    $pcap->setCellClass(1,1,"sum_head_t");
    $pcap->setCellClass(2,1,"sum_head_t");
    $pcap->setCellClass(2,2,"sum_head_t");
    $pcap->setCellClass(2,3,"sum_head_t");
    get_pcap_counts(\%pcap_tabs);
    foreach $key(sort keys %pcap_tabs){
	if($key){
	    $q->param('pcap_rm',$key);
	    $pcap->addRow($pcap_tabs{$key}{"txt"},$pcap_tabs{$key}{"size"},"<a href=\"".$q->url(-query=>1)."\"><img border=0 src=\"button.gif\"></a>");
	}else{
	    $pcap->addRow($pcap_tabs{$key}{"txt"},$pcap_tabs{$key}{"size"},"");
	}
    }
    
    $pcap->addRow("<font size=-3 color=\"red\">".$del_res."</font>","","");

    $q->delete('pcap_rm');

    $table->addRow("Data Management(temporary soln)");
    $table->setCellColSpan(1,1,2);
    $table->setCellClass(1,1,"sum_h");
    
    $table->addRow($hflow->getTable,$pcap->getTable);
    return $table->getTable;
}


sub gen_honeywall_health{

    my $table      = new HTML::Table();
    #my $table      = new HTML::Table(-class=>'summary');
    my $ut_table   = new HTML::Table(-border=>0);
    my $free_table = new HTML::Table;
    my $df_table   = new HTML::Table;
    my $db_table   = new HTML::Table;
    my @line;

    #----- get uptime
    $ENV{"PATH"} = "";
    open(UT,"/usr/bin/uptime |") or warn "unable to run uptime\n";
    
    my $junk;

    $ut_table->addRow("","","Load Average","","");
    $ut_table->setCellColSpan(1,3,3);
    $ut_table->addRow("Uptime","Users","1 Min","5 Min","15 Min");
    while(<UT>){
	@line = split(/,|up/,$_);
	
	($junk,$line[4]) = split(':',$line[4]);
	$ut_table->addRow($line[1].$line[2],$line[3],$line[4],$line[5],$line[6]);
    }
    $ut_table->setColClass(1,"sum_body");
    $ut_table->setColClass(2,"sum_body");
    $ut_table->setColClass(3,"sum_body");
    $ut_table->setColClass(4,"sum_body");
    $ut_table->setColClass(5,"sum_body");
   
    $ut_table->setCellClass(1,3,"sum_head_t");
    
    $ut_table->setCellClass(2,1,"sum_head_t");
    $ut_table->setCellClass(2,2,"sum_head_t");
    $ut_table->setCellClass(2,3,"sum_head_t");
    $ut_table->setCellClass(2,4,"sum_head_t");
    $ut_table->setCellClass(2,5,"sum_head_t");

    #------ get mem usage
    open(DF,"/usr/bin/free -mo| ") or warn "unable to run free\n";
    while(<DF>){
	@line = split(/\s+/,$_);
	$free_table->addRow(@line);	
    }
    $free_table->setColClass(1,"sum_head_l");
    $free_table->setColClass(2,"sum_body");
    $free_table->setColClass(3,"sum_body");
    $free_table->setColClass(4,"sum_body");
    $free_table->setColClass(5,"sum_body");
    $free_table->setColClass(6,"sum_body");
    $free_table->setColClass(7,"sum_body");
   
    $free_table->setCellClass(1,1,"sum_head_t");
    $free_table->setCellClass(1,2,"sum_head_t");
    $free_table->setCellClass(1,3,"sum_head_t");
    $free_table->setCellClass(1,4,"sum_head_t");
    $free_table->setCellClass(1,5,"sum_head_t");
    $free_table->setCellClass(1,6,"sum_head_t");
    $free_table->setCellClass(1,7,"sum_head_t");

    #------ get disk usage
    open(DF,"/bin/df -h | ") or warn "unable to run df\n";
    while(<DF>){
	@line = split(/\s+/,$_);
	$df_table->addRow(@line);
    }
    
    $df_table->setColClass(1,"sum_body");
    $df_table->setColClass(2,"sum_body");
    $df_table->setColClass(3,"sum_body");
    $df_table->setColClass(4,"sum_body");
    $df_table->setColClass(5,"sum_body");
    $df_table->setColClass(6,"sum_body");
    $df_table->setColClass(7,"sum_body");
   
    $df_table->setCellClass(1,1,"sum_head_t");
    $df_table->setCellClass(1,2,"sum_head_t");
    $df_table->setCellClass(1,3,"sum_head_t");
    $df_table->setCellClass(1,4,"sum_head_t");
    $df_table->setCellClass(1,5,"sum_head_t");
    $df_table->setCellClass(1,6,"sum_head_t");
    $df_table->setCellClass(1,7,"sum_head_t");


    #---- build hflow table
    Walleye::Util::setup(1,0,0);
    my %db_tabs;
    $db_table->addRow("Hflow Database");
    $db_table->setCellColSpan(1,1,2);
    $db_table->addRow("DB Table","Count");
    get_db_table_counts(\%db_tabs);
    my $key;
    foreach $key(sort keys %db_tabs){
        $db_table->addRow($key,$db_tabs{$key});
    }
    $db_table->setColClass(1,"sum_head_l");
    $db_table->setColClass(2,"sum_body");
    $db_table->setCellClass(1,1,"sum_head_t");
    $db_table->setCellClass(2,1,"sum_head_t");
    $db_table->setCellClass(2,2,"sum_head_t");
 


    
    #$table->addRow("System Status");
    #$table->setCellClass(1,1,"sum_h");
    $table->addRow($ut_table->getTable);
    $table->addRow($free_table->getTable);
    $table->addRow($df_table->getTable);
    $table->addRow($db_table->getTable);	

    return $table->getTable;
}



sub get_table{
    
    my $table = new HTML::Table(
				-padding=>3,
				-border=>0,
				);

    $table->addRow(gen_honeywall_health());
    #$table->addRow(gen_data_management());
    return $table->getTable;
}
