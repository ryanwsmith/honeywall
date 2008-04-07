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
#----- Flow Detail View
#-----
#----- Version:  $Id: Flow.pm 5673 2008-03-25 12:35:38Z cviecco $
#-----
#----- Authors:  Edward Balas <ebalas@iu.edu>  


package Walleye::Flow;
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
use Walleye::Connection_table;


my $snort_classification_file = "/etc/snort/classification.config";
my $snort_generators_file     = "/etc/snort/generators";

my %snort_class_lut;
my %snort_gen_lut;


sub load_snort_class_lut{
   open(CLASS,"$snort_classification_file")  or warn "unable to open $snort_classification_file\n";

   my $line;
   my $junk;
   my $class;
   my $class_descr;
   my $pri;

   my $x = 1;

   foreach (<CLASS>){
      next if (/(^#)|(^\s+)/);	

      if(/^config classification: (.*)$/){
        $line =  $1;
        ($class,$class_descr,$pri) = split(',',$line);

        $snort_class_lut{$x++} = $class_descr;
     }
   }

}

sub load_snort_gen_lut{
  my $generator;
  my $gen_id;

  my $line;
  my $junk;

  open(GEN,"$snort_generators_file")  or warn "unable to open $snort_generators_file\n";

  foreach (<GEN>){
    next if (/(^#)|(^\s+)/);

    ($line,$junk) = split('#');
    ($generator,$gen_id) = split(/\s+/,$line); 

    $snort_gen_lut{$gen_id} = $generator;
  }
}


#----- Module stuff
require Exporter;
our @ISA=("Exporter");

sub snort_decode{

  my $sensor;
  my $con_id;
  my $rule_eval;

  #ok... this is a really bad icky hack but.. it works.

   #----- sanity check
   if(param('sensor') && param('sensor') =~ /^(\d+)$/){
     $sensor = $1;	
   }

   if(param('con_id') && param('con_id') =~ /^(\d+)$/){
     $con_id = $1;
   }

   if(param('rule_eval') && param('rule_eval') =~  /^(\d+)$/){
     $rule_eval = $1;
   }


  my $tmpdir = File::Temp::tempdir(DIR=>"/var/www/html/walleye/images/",CLEANUP=>1);
  my $filename = $tmpdir."/"."tmp.pcap";

  print header(
                -TYPE => 'text/plain',
                -EXPIRES => 'now',
	        );
   $ENV{"PATH"} = "";

  my $command = "/var/www/html/walleye/pcap_api.pl -M \"sensor=$sensor\" \"con_id=$con_id\"   > $filename";

  system($command);

  if(!$rule_eval){
    system("/usr/sbin/snort-plain -q -v -e  -d -r $filename 2>/dev/null");
  }else{
    system("/usr/sbin/snort-plain -c /etc/snort/snort.conf -A console -l $tmpdir  -r $filename 2>&1");
  }
  return;
}



sub p0f_decode{

  my $sensor;
  my $con_id;

  #ok... this is a really bad icky hack but.. it works.

   #----- sanity check
   if(param('sensor') =~ /^(\d+)$/){
     $sensor = $1;
   }

   if(param('con_id') =~ /^(\d+)$/){
     $con_id = $1;
   }

  my $tmpdir = File::Temp::tempdir(DIR=>"/var/www/html/walleye/images/",CLEANUP=>1);
  my $filename = $tmpdir."/"."tmp.pcap";

  print header(
                -TYPE => 'text/plain',
                -EXPIRES => 'now',
                );
   $ENV{"PATH"} = "";

  my $command = "/var/www/html/walleye/pcap_api.pl -M \"sensor=$sensor\" \"con_id=$con_id\"   > $filename";

  system($command);
  system("/usr/sbin/p0f  -s $filename 2>/dev/null");

  return;
}



sub get_exams{

  my $cgi_copy = new CGI;

  my $table = new  HTML::Table;

  $cgi_copy->param('act','snortdecode');
  $table->addRow('Snort',"<a target=\"new\" href=\"".$cgi_copy->url(-query=>1)."\">Packet Decode</a>");
  $cgi_copy->param('rule_eval','1');
  $table->addRow('Snort',"<a target=\"new\" href=\"".$cgi_copy->url(-query=>1)."\">Rule Evaluation</a>");


  return $table->getTable;

}

sub get_ids{
  my $limit = 10;
  my $page;
  my $start;


  load_snort_gen_lut();
  load_snort_class_lut();

  if(param('ids_page') && param('ids_page') > 0 && param('ids_page') < 1000000){
    $page = param('ids_page');
    $start = ($page -1 ) * $limit;
  }else{
    $page = 1;
    $start = 0;
  }

  my $query  = "select  FROM_UNIXTIME(sec,\"%M %D %H:%I:%S\") , priority, classification, type, sig_name, ";
     $query .= " sig_rev, sig_gen, reference from ids ";
     $query .= " left join ids_sig on ids.sig_id = ids_sig.ids_sig_id  and ids.sig_gen=ids_sig.ids_sig_gen ";
     $query .= " and ids.sensor_id = ids_sig.sensor_id ";
     $query .= " where flow_id = ? and ids.sensor_id = ? ";
     $query .= " order by priority, ids.sec ";
     $query .= " limit $start, $limit ";

  my $sql = $Walleye::Util::dbh->prepare($query);
 
 
  $sql->execute(param('con_id'),param('sensor'));

  my $ref = $sql->fetchall_arrayref();
  my $row_ref;

  my $total_pages;

  my $query2 = "select count(*) from ids  ";
     $query2.= "  where flow_id = ? and ids.sensor_id = ? ";
  
  my $sql2 = $Walleye::Util::dbh->prepare($query2);
  $sql2->execute(param('con_id'),param('sensor'));

  my $ref2 =  $sql2->fetchall_arrayref(); 

 
  if($$ref2[0][0]){
    $total_pages = int($$ref2[0][0] / $limit)+1;
  }else{
    return "";
  }



  #-----
  my $table = new HTML::Table;

  my $counter = 2;

  $table->addRow(Walleye::Util::result_pager($page,$total_pages,"ids_page"));
  $table->setCellColSpan(1,1,8);
  $table->setLastRowClass("et_even");

  $table->addRow("Timestamp","Priority","Classification","Type","Name","Revision","Generator","Reference");
  $table->setLastRowClass("et_even");	
  $table->setCellClass(2,1,"detail_head");
  $table->setCellClass(2,2,"detail_head");	
  $table->setCellClass(2,3,"detail_head");
  $table->setCellClass(2,4,"detail_head");
  $table->setCellClass(2,5,"detail_head");
  $table->setCellClass(2,6,"detail_head");
  $table->setCellClass(2,7,"detail_head");
  $table->setCellClass(2,8,"detail_head");

  foreach $row_ref(@$ref){

	$$row_ref[6] = $snort_gen_lut{$$row_ref[6]};
        $$row_ref[2] = $snort_class_lut{$$row_ref[2]};

	$table->addRow(@$row_ref);
        if($counter++ % 2){
          $table->setLastRowClass("et_even");
        }else{
          $table->setLastRowClass("et_odd");
        }

	$table->setCellClass($counter,1,"detail_body");
        $table->setCellClass($counter,2,"detail_body");
        $table->setCellClass($counter,3,"detail_body");
        $table->setCellClass($counter,4,"detail_body");
        $table->setCellClass($counter,5,"detail_body");
        $table->setCellClass($counter,6,"detail_body");
        $table->setCellClass($counter,7,"detail_body");
  	$table->setCellClass($counter,8,"detail_body");
  }
	
   return $table->getTable;

}

sub get_frame{

   my $table = new HTML::Table(

				);

  

  $table->addRow("Details for this flow");
  $table->setCellClass(1,1,"sum_h");	
  $table->addRow(Walleye::Connection_table::get_frame());
  $table->addRow("IDS details");
  $table->setCellClass(3,1,"sum_h");
  $table->addRow(get_ids());
  $table->addRow("Flow Examination");
  $table->setCellClass(5,1,"sum_h");
  $table->addRow(get_exams());	


  $table->getTable;
}
